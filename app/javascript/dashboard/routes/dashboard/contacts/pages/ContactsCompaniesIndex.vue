<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import ContactAPI from 'dashboard/api/contacts';

import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';

const PAGE_SIZE = 15;

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const companies = ref([]);
const meta = ref({ count: 0, current_page: 1 });
const isLoading = ref(false);
const searchValue = ref(route.query.search || '');

const currentPage = computed(() => Number(route.query.page) || 1);
const totalItems = computed(() => Number(meta.value.count) || 0);

const fetchCompanies = async () => {
  isLoading.value = true;
  try {
    const { data } = await ContactAPI.getCompanies(
      currentPage.value,
      searchValue.value
    );
    companies.value = data.payload || [];
    meta.value = data.meta || {};
  } finally {
    isLoading.value = false;
  }
};

const replaceQuery = query => {
  router.replace({
    name: 'contacts_companies_index',
    query: { ...route.query, ...query },
  });
};

const applySearch = debounce(value => {
  replaceQuery({ search: value || undefined, page: 1 });
}, 300);

const onSearch = value => {
  searchValue.value = value;
  applySearch(value);
};

const onPageChange = page => {
  replaceQuery({ page, search: searchValue.value || undefined });
};

const openCompany = name => {
  router.push({
    name: 'contacts_dashboard_index',
    query: { company: name, page: 1 },
  });
};

watch(
  [currentPage, () => route.query.search],
  () => {
    searchValue.value = route.query.search || '';
    fetchCompanies();
  },
  { immediate: true }
);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header
      class="flex items-center justify-between gap-4 px-6 h-[3.25rem] border-b border-n-weak"
    >
      <h1 class="text-base font-medium text-n-slate-12">
        {{ t('COMPANIES.HEADER') }}
      </h1>
      <div class="w-64">
        <Input
          :model-value="searchValue"
          :placeholder="t('COMPANIES.SEARCH_PLACEHOLDER')"
          @update:model-value="onSearch"
        />
      </div>
    </header>

    <main class="flex-1 px-6 py-4 overflow-y-auto">
      <div v-if="isLoading" class="flex justify-center py-10">
        <Spinner />
      </div>
      <p
        v-else-if="!companies.length"
        class="py-10 text-center text-n-slate-11"
      >
        {{ t('COMPANIES.EMPTY') }}
      </p>
      <div v-else class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <button
          v-for="company in companies"
          :key="company.name"
          type="button"
          class="flex flex-col gap-1 p-4 text-left border rounded-lg border-n-weak bg-n-alpha-1 hover:bg-n-alpha-2"
          @click="openCompany(company.name)"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ company.name }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('COMPANIES.CONTACTS_COUNT', { n: company.contacts_count }) }}
          </span>
        </button>
      </div>
    </main>

    <PaginationFooter
      v-if="totalItems > PAGE_SIZE"
      current-page-info="CONTACTS_LAYOUT.PAGINATION_FOOTER.SHOWING"
      :current-page="currentPage"
      :total-items="totalItems"
      :items-per-page="PAGE_SIZE"
      @update:current-page="onPageChange"
    />
  </section>
</template>
