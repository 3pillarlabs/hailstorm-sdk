import { FixedDate } from './FixedDate';

describe('FixedDate', () => {
  const epoch = new FixedDate(new Date(2020, 2, 31, 15, 22, 33));

  it('should format relative to a time on current date', () => {
    expect(epoch.formatDistance(new Date(2020, 2, 31, 10, 30, 19))).toEqual('10:30 AM');
  });

  it('should format relative to a day and time on previous dates in same month', () => {
    expect(epoch.formatDistance(new Date(2020, 2, 21, 10, 30, 19))).toEqual('Sat 21st 10:30 AM');
  });

  it('should format relative to a month, day and time on a date in previous months', () => {
    expect(epoch.formatDistance(new Date(2020, 1, 21, 10, 30, 19))).toEqual('Feb 21st 10:30 AM');
  });

  it('should format relative to a year, month, day and time on a date in previous years', () => {
    expect(epoch.formatDistance(new Date(2019, 11, 21, 10, 30, 19))).toEqual('2019 Dec 21st 10:30 AM');
  });
});
