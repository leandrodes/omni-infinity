import {
  generateTimeSlots,
  getTime,
  timeSlotParse,
  timeSlotTransform,
  timeZoneOptions,
} from '../businessHour';

describe('#generateTimeSlots', () => {
  it('returns correct number of time slots for 15-minute intervals', () => {
    const slots = generateTimeSlots(15);
    expect(slots.length).toStrictEqual(97);
  });

  it('returns correct number of time slots for 30-minute intervals', () => {
    const slots = generateTimeSlots(30);
    expect(slots.length).toStrictEqual(49);
  });

  it('returns correct time slots for 4-hour intervals', () => {
    expect(generateTimeSlots(240)).toStrictEqual([
      '00:00',
      '04:00',
      '08:00',
      '12:00',
      '16:00',
      '20:00',
      '23:59',
    ]);
  });

  it('always starts with 00:00', () => {
    expect(generateTimeSlots(15)[0]).toStrictEqual('00:00');
    expect(generateTimeSlots(30)[0]).toStrictEqual('00:00');
    expect(generateTimeSlots(60)[0]).toStrictEqual('00:00');
  });

  it('always ends with 23:59', () => {
    const slots15 = generateTimeSlots(15);
    const slots30 = generateTimeSlots(30);
    const slots60 = generateTimeSlots(60);

    expect(slots15[slots15.length - 1]).toStrictEqual('23:59');
    expect(slots30[slots30.length - 1]).toStrictEqual('23:59');
    expect(slots60[slots60.length - 1]).toStrictEqual('23:59');
  });

  it('does not duplicate 23:59 if it already exists in regular intervals', () => {
    const slots = generateTimeSlots(1);
    const count23_59 = slots.filter(slot => slot === '23:59').length;
    expect(count23_59).toStrictEqual(1);
  });

  it('handles edge case with very large step', () => {
    const slots = generateTimeSlots(1440);
    expect(slots).toStrictEqual(['00:00', '23:59']);
  });
});

describe('#getTime', () => {
  it('returns 24 hour time correctly', () => {
    expect(getTime(15, 30)).toStrictEqual('15:30');
    expect(getTime(0, 5)).toStrictEqual('00:05');
  });
});

describe('#timeSlotParse', () => {
  it('parses first and second periods correctly', () => {
    const slot = {
      day_of_week: 1,
      open_hour: 8,
      open_minutes: 0,
      close_hour: 11,
      close_minutes: 59,
      closed_all_day: false,
      open_all_day: false,
      second_period_enabled: true,
      second_open_hour: 13,
      second_open_minutes: 0,
      second_close_hour: 18,
      second_close_minutes: 0,
    };

    expect(timeSlotParse([slot])).toStrictEqual([
      {
        day: 1,
        from: '08:00',
        to: '11:59',
        from2: '13:00',
        to2: '18:00',
        secondPeriodEnabled: true,
        valid: true,
        valid2: true,
        openAllDay: false,
      },
    ]);
  });
});

describe('#timeSlotTransform', () => {
  it('transforms first and second periods correctly', () => {
    const slot = {
      day: 1,
      from: '08:00',
      to: '11:59',
      from2: '13:00',
      to2: '18:00',
      secondPeriodEnabled: true,
      valid: true,
      valid2: true,
      openAllDay: false,
    };

    expect(timeSlotTransform([slot])).toStrictEqual([
      {
        day_of_week: 1,
        open_hour: 8,
        open_minutes: 0,
        close_hour: 11,
        close_minutes: 59,
        closed_all_day: false,
        open_all_day: false,
        second_period_enabled: true,
        second_open_hour: 13,
        second_open_minutes: 0,
        second_close_hour: 18,
        second_close_minutes: 0,
      },
    ]);
  });
});

describe('#timeZoneOptions', () => {
  it('returns transforms correctly', () => {
    expect(timeZoneOptions()[0]).toStrictEqual({
      value: 'Etc/GMT+12',
      label: 'International Date Line West (GMT−12:00)',
    });
  });
});
