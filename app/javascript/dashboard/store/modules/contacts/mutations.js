import types from '../../mutation-types';
import * as Sentry from '@sentry/vue';

export const mutations = {
  [types.SET_CONTACT_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },

  [types.CLEAR_CONTACTS]: $state => {
    $state.records = {};
    $state.sortOrder = [];
  },

  [types.SET_CONTACT_META]: ($state, data) => {
    const { count, current_page: currentPage, has_more: hasMore } = data;
    $state.meta.count = count;
    $state.meta.currentPage = currentPage;
    if (hasMore !== undefined) {
      $state.meta.hasMore = hasMore;
    }
  },

  [types.APPEND_CONTACTS]: ($state, data) => {
    data.forEach(contact => {
      $state.records[contact.id] = {
        ...($state.records[contact.id] || {}),
        ...contact,
      };
      if (!$state.sortOrder.includes(contact.id)) {
        $state.sortOrder.push(contact.id);
      }
    });
  },

  [types.SET_CONTACTS]: ($state, data) => {
    const sortOrder = data.map(contact => {
      $state.records[contact.id] = {
        ...($state.records[contact.id] || {}),
        ...contact,
      };
      return contact.id;
    });
    $state.sortOrder = sortOrder;
  },

  [types.SET_CONTACT_ITEM]: ($state, data) => {
    $state.records[data.id] = {
      ...($state.records[data.id] || {}),
      ...data,
    };

    if (!$state.sortOrder.includes(data.id)) {
      $state.sortOrder.push(data.id);
    }
  },

  [types.EDIT_CONTACT]: ($state, data) => {
    const existingAttachments = $state.records[data.id]?.attachments;
    const existingContactFiles = $state.records[data.id]?.contact_files;
    $state.records[data.id] = {
      ...data,
      ...(existingAttachments && { attachments: existingAttachments }),
      ...(existingContactFiles && { contact_files: existingContactFiles }),
    };
  },

  [types.SET_CONTACT_ATTACHMENTS]: ($state, { id, data }) => {
    if (!$state.records[id]) $state.records[id] = {};
    $state.records[id].attachments = data;
  },

  [types.SET_CONTACT_FILES]: ($state, { id, data }) => {
    if (!$state.records[id]) $state.records[id] = {};
    $state.records[id].contact_files = data;
  },

  [types.DELETE_CONTACT_FILE]: ($state, { id, fileId }) => {
    const contact = $state.records[id];
    if (!contact?.contact_files) return;

    contact.contact_files = contact.contact_files.filter(
      file => String(file.id) !== String(fileId)
    );
  },

  [types.DELETE_CONTACT]: ($state, id) => {
    const index = $state.sortOrder.findIndex(item => item === id);
    $state.sortOrder.splice(index, 1);
    delete $state.records[id];
  },

  [types.UPDATE_CONTACTS_PRESENCE]: ($state, data) => {
    Object.values($state.records).forEach(element => {
      let availabilityStatus;
      try {
        availabilityStatus = data[element.id];
      } catch (error) {
        Sentry.setContext('contact is undefined', {
          records: $state.records,
          data: data,
        });
        Sentry.captureException(error);

        return;
      }
      if (availabilityStatus) {
        $state.records[element.id].availability_status = availabilityStatus;
      } else {
        $state.records[element.id].availability_status = null;
      }
    });
  },

  [types.SET_CONTACT_FILTERS](_state, data) {
    _state.appliedFilters = data;
  },

  [types.CLEAR_CONTACT_FILTERS](_state) {
    _state.appliedFilters = [];
  },
};
