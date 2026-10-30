export const teamVisibilitySettingsEnabled = settings =>
  settings?.hide_conversations_assigned_to_others === true &&
  settings?.show_conversations_only_from_user_teams === true;

const numericTeamIds = agent =>
  (agent?.team_ids || []).map(teamId => Number(teamId));

export const agentBelongsToTeam = (agent, teamId) =>
  numericTeamIds(agent).includes(Number(teamId));

export const assignmentTeamConflict = ({ agent, conversations, settings }) => {
  if (!teamVisibilitySettingsEnabled(settings)) return false;
  if (!agent || agent.assignee_type === 'AgentBot') return false;
  if (agent.role === 'administrator') return false;

  return conversations.filter(Boolean).some(conversation => {
    const teamId = conversation.meta?.team?.id;
    if (!teamId || conversation.visibility === 'restricted') return false;

    return !agentBelongsToTeam(agent, teamId);
  });
};

export const teamsForAgent = (agent, teams = []) =>
  teams.filter(team => agentBelongsToTeam(agent, team.id));
