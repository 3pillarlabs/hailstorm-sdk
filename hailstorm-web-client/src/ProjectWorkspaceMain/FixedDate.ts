import { differenceInHours, format, differenceInMonths, differenceInYears, getYear } from "date-fns";

export class FixedDate {

  constructor(private epoch: Date) {}

  formatDistance(toDate: Date): string {
    const filters: [() => boolean, string][] = [
      [() => differenceInHours(this.epoch, toDate) < 24, 'h:mm aaa'],
      [() => differenceInMonths(this.epoch, toDate) < 1, 'ccc do h:mm aaa'],
      [() => getYear(toDate) < getYear(this.epoch), 'yyyy MMM do h:mm aaa']
    ];

    const [_, fmt] = filters.find(([predicate, _]) => predicate()) || [() => true, 'MMM do h:mm aaa'];
    return format(toDate, fmt);
  }
}
