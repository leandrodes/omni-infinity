<script>
import differenceInMinutes from 'date-fns/differenceInMinutes';
import { generateTimeSlots } from '../helpers/businessHour';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextSelect from 'dashboard/components-next/select/Select.vue';

const timeOptions = generateTimeSlots(30).map(value => ({
  value,
  label: value,
}));

const timeToDate = value => {
  const [hour = 0, minute = 0] = value.split(':').map(Number);
  return new Date(1970, 0, 1, hour, minute);
};

const isValidRange = (from, to) => {
  if (!from || !to) return false;
  return differenceInMinutes(timeToDate(to), timeToDate(from)) > 0;
};

const rangeMinutes = (from, to) => {
  if (!isValidRange(from, to)) return 0;
  return differenceInMinutes(timeToDate(to), timeToDate(from));
};

export default {
  components: {
    Icon,
    NextSelect,
  },
  props: {
    dayName: {
      type: String,
      required: true,
    },
    timeSlot: {
      type: Object,
      default: () => ({
        from: '',
        to: '',
        from2: '',
        to2: '',
        secondPeriodEnabled: false,
        valid2: true,
      }),
    },
  },
  emits: ['update'],
  data() {
    return { timeOptions };
  },
  computed: {
    isDayEnabled: {
      get() {
        return Boolean(this.timeSlot.from && this.timeSlot.to);
      },
      set(value) {
        const newSlot = value
          ? {
              ...this.timeSlot,
              from: '08:00',
              to: '18:00',
              valid: true,
              openAllDay: false,
            }
          : {
              ...this.timeSlot,
              from: '',
              to: '',
              from2: '',
              to2: '',
              secondPeriodEnabled: false,
              valid: false,
              valid2: true,
              openAllDay: false,
            };
        this.$emit('update', newSlot);
      },
    },
    fromTime: {
      get() {
        return this.timeSlot.from;
      },
      set(value) {
        this.$emit('update', {
          ...this.timeSlot,
          from: value,
          valid: isValidRange(value, this.timeSlot.to),
        });
      },
    },
    toTime: {
      get() {
        return this.timeSlot.to;
      },
      set(value) {
        this.$emit('update', {
          ...this.timeSlot,
          to: value,
          valid: isValidRange(this.timeSlot.from, value),
        });
      },
    },
    secondPeriodEnabled: {
      get() {
        return this.timeSlot.secondPeriodEnabled;
      },
      set(value) {
        this.$emit('update', {
          ...this.timeSlot,
          secondPeriodEnabled: value,
          from2: value ? this.timeSlot.from2 || '13:00' : '',
          to2: value ? this.timeSlot.to2 || '18:00' : '',
          valid2:
            !value ||
            isValidRange(
              this.timeSlot.from2 || '13:00',
              this.timeSlot.to2 || '18:00'
            ),
        });
      },
    },
    fromTime2: {
      get() {
        return this.timeSlot.from2;
      },
      set(value) {
        this.$emit('update', {
          ...this.timeSlot,
          from2: value,
          valid2: isValidRange(value, this.timeSlot.to2),
        });
      },
    },
    toTime2: {
      get() {
        return this.timeSlot.to2;
      },
      set(value) {
        this.$emit('update', {
          ...this.timeSlot,
          to2: value,
          valid2: isValidRange(this.timeSlot.from2, value),
        });
      },
    },
    totalHours() {
      if (this.timeSlot.openAllDay) return '24h';

      const totalMinutes =
        rangeMinutes(this.timeSlot.from, this.timeSlot.to) +
        (this.secondPeriodEnabled
          ? rangeMinutes(this.timeSlot.from2, this.timeSlot.to2)
          : 0);
      const [h, m] = [Math.floor(totalMinutes / 60), totalMinutes % 60];

      return [h && `${h}h`, m && `${m}m`].filter(Boolean).join(' ') || '0m';
    },
    hasError() {
      return (
        !this.timeSlot.valid ||
        (this.secondPeriodEnabled && !this.timeSlot.valid2)
      );
    },
    isOpenAllDay: {
      get() {
        return this.timeSlot.openAllDay;
      },
      set(value) {
        if (value) {
          this.$emit('update', {
            ...this.timeSlot,
            from: '00:00',
            to: '23:59',
            from2: '',
            to2: '',
            secondPeriodEnabled: false,
            valid: true,
            valid2: true,
            openAllDay: value,
          });
        } else {
          this.$emit('update', {
            ...this.timeSlot,
            from: '08:00',
            to: '18:00',
            valid: true,
            openAllDay: value,
          });
        }
      },
    },
  },
};
</script>

<template>
  <tr>
    <td class="ltr:pl-4 ltr:pr-3 rtl:pl-3 rtl:pr-4">
      <div class="flex items-center gap-2 min-h-16">
        <input
          v-model="isDayEnabled"
          name="enable-day"
          class="m-0"
          type="checkbox"
          :title="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.ENABLE')"
        />
        <span class="text-body-main text-n-slate-12 font-medium">
          {{ dayName }}
        </span>
      </div>
    </td>
    <td class="py-3 ltr:pr-3 rtl:pl-3">
      <div v-if="isDayEnabled" class="flex flex-col gap-2">
        <div class="flex flex-wrap items-center gap-3">
          <div class="flex items-center gap-2">
            <input
              v-model="isOpenAllDay"
              name="enable-open-all-day"
              class="m-0"
              type="checkbox"
              :title="$t('INBOX_MGMT.BUSINESS_HOURS.ALL_DAY')"
            />
            <span class="text-body-main text-n-slate-12">
              {{ $t('INBOX_MGMT.BUSINESS_HOURS.ALL_DAY') }}
            </span>
          </div>
          <NextSelect
            v-model="fromTime"
            :options="timeOptions"
            :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
            :disabled="isOpenAllDay"
          />
          <div class="flex items-center">
            <Icon icon="i-lucide-minus" class="size-4" />
          </div>
          <NextSelect
            v-model="toTime"
            :options="timeOptions"
            :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
            :disabled="isOpenAllDay"
          />
        </div>

        <label v-if="!isOpenAllDay" class="flex items-center gap-2">
          <input v-model="secondPeriodEnabled" type="checkbox" class="m-0" />
          <span class="text-body-main text-n-slate-11">
            {{ $t('INBOX_MGMT.BUSINESS_HOURS.SECOND_PERIOD') }}
          </span>
        </label>

        <div
          v-if="secondPeriodEnabled"
          class="flex flex-wrap items-center gap-3"
        >
          <NextSelect
            v-model="fromTime2"
            :options="timeOptions"
            :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
          />
          <div class="flex items-center">
            <Icon icon="i-lucide-minus" class="size-4" />
          </div>
          <NextSelect
            v-model="toTime2"
            :options="timeOptions"
            :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
          />
        </div>

        <span v-if="hasError" class="error text-label-small text-n-ruby-9">
          {{ $t('INBOX_MGMT.BUSINESS_HOURS.DAY.VALIDATION_ERROR') }}
        </span>
      </div>
      <span v-else class="text-body-main text-n-slate-11">
        {{ $t('INBOX_MGMT.BUSINESS_HOURS.DAY.UNAVAILABLE') }}
      </span>
    </td>
    <td class="py-3 ltr:pr-3 rtl:pl-3">
      <span
        v-if="isDayEnabled && !hasError"
        class="label bg-n-blue-3 text-n-blue-11 text-label-small inline-block px-2 py-1 rounded-lg cursor-default whitespace-nowrap"
      >
        {{ totalHours }}
      </span>
    </td>
  </tr>
</template>
