<!-- eslint-disable vue/v-slot-style -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import ContactDetailsItem from './ContactDetailsItem.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import ConversationLabels from './labels/LabelBox.vue';
import { CONVERSATION_PRIORITY } from '../../../../shared/constants/messages';
import { CONVERSATION_EVENTS } from '../../../helper/AnalyticsHelper/events';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AssignmentTeamConflictModal from 'dashboard/components-next/ConversationWorkflow/AssignmentTeamConflictModal.vue';
import { assignmentTeamConflict } from 'dashboard/helper/assignmentTeamHelper';
import { useAccount } from 'dashboard/composables/useAccount';
import NextSwitch from 'dashboard/components-next/switch/Switch.vue';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

export default {
  components: {
    ContactDetailsItem,
    NextSwitch,
    MultiselectDropdown,
    ConversationLabels,
    NextButton,
    AssignmentTeamConflictModal,
  },
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },
  setup() {
    const { agentsList } = useAgentsList(true, {
      includeAIAssignees: true,
    });
    const { currentAccount } = useAccount();
    return {
      agentsList,
      currentAccount,
    };
  },
  data() {
    return {
      pendingAgent: null,
      priorityOptions: [
        {
          id: null,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.NONE'),
          icon: 'i-woot-priority-empty',
        },
        {
          id: CONVERSATION_PRIORITY.URGENT,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.URGENT'),
          icon: 'i-woot-priority-urgent',
        },
        {
          id: CONVERSATION_PRIORITY.HIGH,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.HIGH'),
          icon: 'i-woot-priority-high',
        },
        {
          id: CONVERSATION_PRIORITY.MEDIUM,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM'),
          icon: 'i-woot-priority-medium',
        },
        {
          id: CONVERSATION_PRIORITY.LOW,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.LOW'),
          icon: 'i-woot-priority-low',
        },
      ],
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUser: 'getCurrentUser',
      currentUserRole: 'getCurrentRole',
      teams: 'teams/getTeams',
    }),
    hasAnAssignedTeam() {
      return !!this.currentChat?.meta?.team;
    },
    teamsList() {
      if (this.hasAnAssignedTeam) {
        return [
          { id: 0, name: this.$t('TEAMS_SETTINGS.LIST.NONE') },
          ...this.teams,
        ];
      }
      return this.teams;
    },
    assignedAgent: {
      get() {
        const assignee = this.currentChat.meta.assignee;
        return (
          assignee && {
            ...assignee,
            assignee_type: this.currentChat.meta.assignee_type || 'User',
          }
        );
      },
      set(agent) {
        this.attemptAssignAgent(agent);
      },
    },
    assignedTeam: {
      get() {
        return this.currentChat.meta.team;
      },
      set(team) {
        const conversationId = this.currentChat.id;
        const previousTeamId = this.currentChat.meta.team?.id;
        const teamId = team ? team.id : 0;
        this.$store.dispatch('setCurrentChatTeam', { team, conversationId });
        this.$store
          .dispatch('assignTeam', { conversationId, teamId })
          .then(() => {
            if (Number(teamId) !== Number(previousTeamId || 0)) {
              emitter.emit(
                BUS_EVENTS.CONVERSATION_ACCESS_REVOKED,
                conversationId
              );
            }
            useAlert(this.$t('CONVERSATION.CHANGE_TEAM'));
          });
      },
    },
    assignedPriority: {
      get() {
        const selectedOption = this.priorityOptions.find(
          opt => opt.id === this.currentChat.priority
        );

        return selectedOption || this.priorityOptions[0];
      },
      set(priorityItem) {
        const conversationId = this.currentChat.id;
        const oldValue = this.currentChat?.priority;
        const priority = priorityItem.id;

        this.$store.dispatch('setCurrentChatPriority', {
          priority,
          conversationId,
        });
        this.$store
          .dispatch('assignPriority', { conversationId, priority })
          .then(() => {
            useTrack(CONVERSATION_EVENTS.CHANGE_PRIORITY, {
              oldValue,
              newValue: priority,
              from: 'Conversation Sidebar',
            });
            useAlert(
              this.$t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
                priority: priorityItem.name,
                conversationId,
              })
            );
          });
      },
    },
    isPrivateConversation() {
      return this.currentChat?.visibility === 'restricted';
    },
    canManagePrivacy() {
      if (this.currentUserRole === 'administrator') return true;

      return (
        this.currentChat?.meta?.assignee?.id === this.currentUser?.id ||
        this.currentChat?.private_owner_id === this.currentUser?.id
      );
    },
    showSelfAssign() {
      if (!this.assignedAgent) {
        return true;
      }
      if (
        this.assignedAgent.id !== this.currentUser.id ||
        (this.assignedAgent.assignee_type || 'User') !== 'User'
      ) {
        return true;
      }
      return false;
    },
  },
  methods: {
    commitAssignAgent(agent, team = null, note = '') {
      const agentId = agent ? agent.id : null;
      const assigneeType = agent ? agent.assignee_type || 'User' : null;
      const conversationId = this.currentChat.id;
      const previousTeamId = this.currentChat.meta.team?.id;

      this.$store
        .dispatch('assignAgent', {
          conversationId,
          agentId,
          assigneeType,
          teamId: team?.id,
          note,
        })
        .then(() => {
          if (team) {
            this.$store.dispatch('setCurrentChatTeam', {
              team,
              conversationId,
            });
          }
          const assignedToOtherAgent =
            agentId && Number(agentId) !== Number(this.currentUser.id);
          const teamChanged =
            team && Number(team.id) !== Number(previousTeamId || 0);

          if (assignedToOtherAgent || teamChanged) {
            emitter.emit(
              BUS_EVENTS.CONVERSATION_ACCESS_REVOKED,
              conversationId
            );
          }
          useAlert(this.$t('CONVERSATION.CHANGE_AGENT'));
        })
        .catch(() => {
          useAlert(this.$t('CONVERSATION.CHANGE_AGENT_FAILED'));
        });
    },

    attemptAssignAgent(agent) {
      const hasConflict = assignmentTeamConflict({
        agent,
        conversations: [this.currentChat],
        settings: this.currentAccount?.settings || {},
      });

      if (!hasConflict) {
        this.commitAssignAgent(agent);
        return;
      }

      this.pendingAgent = agent;
      this.$nextTick(() => {
        this.$refs.assignmentConflictModal?.open();
      });
    },

    onConfirmAssignmentTeam({ team, note }) {
      const agent = this.pendingAgent;
      this.pendingAgent = null;
      this.commitAssignAgent(agent, team, note);
    },

    onCloseAssignmentConflict() {
      this.pendingAgent = null;
    },

    onSelfAssign() {
      const {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        avatar_url,
      } = this.currentUser;
      const selfAssign = {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        thumbnail: avatar_url,
      };
      this.assignedAgent = selfAssign;
    },
    onClickAssignAgent(selectedItem) {
      if (
        this.assignedAgent?.id === selectedItem.id &&
        (this.assignedAgent?.assignee_type || 'User') ===
          (selectedItem.assignee_type || 'User')
      ) {
        this.assignedAgent = null;
      } else {
        this.assignedAgent = selectedItem;
      }
    },

    onClickAssignTeam(selectedItemTeam) {
      if (this.assignedTeam && this.assignedTeam.id === selectedItemTeam.id) {
        this.assignedTeam = null;
      } else {
        this.assignedTeam = selectedItemTeam;
      }
    },

    async onTogglePrivacy(value) {
      try {
        await this.$store.dispatch('toggleConversationVisibility', {
          conversationId: this.currentChat.id,
          restricted: value,
        });
        useAlert(
          value
            ? this.$t('CONVERSATION.PRIVACY.ENABLED')
            : this.$t('CONVERSATION.PRIVACY.DISABLED')
        );
      } catch {
        useAlert(this.$t('CONVERSATION.PRIVACY.ERROR'));
      }
    },

    onClickAssignPriority(selectedPriorityItem) {
      const isSamePriority =
        this.assignedPriority &&
        this.assignedPriority.id === selectedPriorityItem.id;

      this.assignedPriority = isSamePriority
        ? this.priorityOptions[0]
        : selectedPriorityItem;
    },
  },
};
</script>

<template>
  <div>
    <div>
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL')"
      >
        <template #button>
          <NextButton
            v-if="showSelfAssign"
            link
            xs
            icon="i-lucide-arrow-right"
            class="!gap-1"
            :label="$t('CONVERSATION_SIDEBAR.SELF_ASSIGN')"
            @click="onSelfAssign"
          />
        </template>
      </ContactDetailsItem>
      <MultiselectDropdown
        :options="agentsList"
        :selected-item="assignedAgent"
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.AGENT')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
        :no-search-result="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
        "
        :input-placeholder="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
        "
        @select="onClickAssignAgent"
      />
    </div>
    <div>
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.TEAM_LABEL')"
      />
      <MultiselectDropdown
        :options="teamsList"
        :selected-item="assignedTeam"
        show-emoji-icon
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.TEAM')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
        :no-search-result="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.TEAM')
        "
        :input-placeholder="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.TEAM')
        "
        @select="onClickAssignTeam"
      />
    </div>
    <div>
      <ContactDetailsItem compact :title="$t('CONVERSATION.PRIORITY.TITLE')" />
      <MultiselectDropdown
        :options="priorityOptions"
        :selected-item="assignedPriority"
        :multiselector-title="$t('CONVERSATION.PRIORITY.TITLE')"
        :multiselector-placeholder="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SELECT_PLACEHOLDER')
        "
        :no-search-result="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.NO_RESULTS')
        "
        :input-placeholder="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.INPUT_PLACEHOLDER')
        "
        @select="onClickAssignPriority"
      />
    </div>
    <div v-if="canManagePrivacy" class="flex flex-col gap-2">
      <ContactDetailsItem compact :title="$t('CONVERSATION.PRIVACY.TITLE')" />
      <div class="flex items-center justify-between gap-4 px-1">
        <span class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION.PRIVACY.DESCRIPTION') }}
        </span>
        <NextSwitch
          :model-value="isPrivateConversation"
          @update:model-value="onTogglePrivacy"
        />
      </div>
    </div>
    <ContactDetailsItem
      compact
      :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_LABELS')"
    />
    <ConversationLabels :conversation-id="conversationId" />
    <AssignmentTeamConflictModal
      ref="assignmentConflictModal"
      :agent="pendingAgent"
      :teams="teams"
      :conversation-count="1"
      @confirm="onConfirmAssignmentTeam"
      @close="onCloseAssignmentConflict"
    />
  </div>
</template>
