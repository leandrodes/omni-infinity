<script setup>
import { onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import CampaignsTypeNav from 'dashboard/components-next/Campaigns/CampaignsTypeNav.vue';

defineProps({
  keepAlive: { type: Boolean, default: true },
});

const store = useStore();

onMounted(() => {
  store.dispatch('campaigns/get');
  store.dispatch('labels/get');
});
</script>

<template>
  <div
    class="flex flex-col justify-between flex-1 h-full m-0 overflow-auto bg-n-surface-1"
  >
    <CampaignsTypeNav />
    <router-view v-slot="{ Component }">
      <keep-alive v-if="keepAlive">
        <component :is="Component" />
      </keep-alive>
      <component :is="Component" v-else />
    </router-view>
  </div>
</template>
