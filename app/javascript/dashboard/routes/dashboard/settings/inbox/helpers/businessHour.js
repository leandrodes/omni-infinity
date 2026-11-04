import timeZoneData from './timezones.json';

export const defaultTimeSlot = [
  {
    day: 0,
    to: '',
    from: '',
    to2: '',
    from2: '',
    secondPeriodEnabled: false,
    valid: false,
    valid2: true,
  },
  {
    day: 1,
    to: '',
    from: '',
    to2: '',
    from2: '',
    secondPeriodEnabled: false,
    valid: false,
    valid2: true,
  },
  {
    day: 2,
    to: '',
    from: '',
    to2: '',
    from2: '',
    secondPeriodEnabled: false,
    valid: false,
    valid2: true,
  },
  {
    day: 3,
    to: '',
    from: '',
    to2: '',
    from2: '',
    secondPeriodEnabled: false,
    valid: false,
    valid2: true,
  },
  {
    day: 4,
    to: '',
    from: '',
    to2: '',
    from2: '',
    secondPeriodEnabled: false,
    valid: false,
    valid2: true,
  },
  {
    day: 5,
    to: '',
    from: '',
    to2: '',
    from2: '',
    secondPeriodEnabled: false,
    valid: false,
    valid2: true,
  },
  {
    day: 6,
    to: '',
    from: '',
    to2: '',
    from2: '',
    secondPeriodEnabled: false,
    valid: false,
    valid2: true,
  },
];

export const generateTimeSlots = (step = 15) => {
  const slots = [];
  for (let minutes = 0; minutes < 24 * 60; minutes += step) {
    const hour = String(Math.floor(minutes / 60)).padStart(2, '0');
    const minute = String(minutes % 60).padStart(2, '0');
    slots.push(`${hour}:${minute}`);
  }

  if (!slots.includes('23:59')) slots.push('23:59');
  return slots;
};

export const getTime = (hour, minute) => {
  const parsedHour = String(hour || 0).padStart(2, '0');
  const parsedMinute = String(minute || 0).padStart(2, '0');
  return `${parsedHour}:${parsedMinute}`;
};

const parseTime = value => {
  const normalized = value?.toString().trim().replace('.', ':') || '';
  const match = /^(\d{1,2}):?(\d{2})$/.exec(normalized);
  if (!match) return { hour: 0, minute: 0 };

  return { hour: Number(match[1]), minute: Number(match[2]) };
};

export const timeSlotParse = timeSlots => {
  return timeSlots.map(slot => {
    const {
      day_of_week: day,
      open_hour: openHour,
      open_minutes: openMinutes,
      close_hour: closeHour,
      close_minutes: closeMinutes,
      closed_all_day: closedAllDay,
      open_all_day: openAllDay,
      second_period_enabled: secondPeriodEnabled,
      second_open_hour: secondOpenHour,
      second_open_minutes: secondOpenMinutes,
      second_close_hour: secondCloseHour,
      second_close_minutes: secondCloseMinutes,
    } = slot;
    const from = closedAllDay ? '' : getTime(openHour, openMinutes);
    const to = closedAllDay ? '' : getTime(closeHour, closeMinutes);
    const showSecondPeriod = !closedAllDay && !!secondPeriodEnabled;
    const from2 = showSecondPeriod
      ? getTime(secondOpenHour, secondOpenMinutes)
      : '';
    const to2 = showSecondPeriod
      ? getTime(secondCloseHour, secondCloseMinutes)
      : '';

    return {
      day,
      to,
      from,
      to2,
      from2,
      secondPeriodEnabled: showSecondPeriod,
      valid: !closedAllDay,
      valid2: !showSecondPeriod || !!(from2 && to2),
      openAllDay,
    };
  });
};

export const timeSlotTransform = timeSlots => {
  return timeSlots.map(slot => {
    const closed = slot.openAllDay ? false : !(slot.to && slot.from);
    const openAllDay = slot.openAllDay;
    const primary = closed ? null : parseTime(slot.from);
    const secondary =
      !closed && slot.secondPeriodEnabled && slot.from2 && slot.to2
        ? parseTime(slot.from2)
        : null;
    const secondaryEnd =
      !closed && slot.secondPeriodEnabled && slot.from2 && slot.to2
        ? parseTime(slot.to2)
        : null;
    const primaryEnd = closed ? null : parseTime(slot.to);

    return {
      day_of_week: slot.day,
      closed_all_day: closed,
      open_hour: primary?.hour ?? '',
      open_minutes: primary?.minute ?? '',
      close_hour: primaryEnd?.hour ?? '',
      close_minutes: primaryEnd?.minute ?? '',
      open_all_day: openAllDay,
      second_period_enabled: !!secondary,
      second_open_hour: secondary?.hour ?? '',
      second_open_minutes: secondary?.minute ?? '',
      second_close_hour: secondaryEnd?.hour ?? '',
      second_close_minutes: secondaryEnd?.minute ?? '',
    };
  });
};

export const timeZoneOptions = () => {
  return Object.keys(timeZoneData).map(key => ({
    label: key,
    value: timeZoneData[key],
  }));
};
