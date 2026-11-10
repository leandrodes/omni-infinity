// Assignment order types
export const BALANCED = 'balanced';
export const PRIORITY = 'priority';
export const SEQUENTIAL = 'sequential';

// Assignment priority types
export const EARLIEST_CREATED = 'earliest_created';
export const LONGEST_WAITING = 'longest_waiting';

// Default values for fair distribution
export const DEFAULT_FAIR_DISTRIBUTION_LIMIT = 100;
export const DEFAULT_FAIR_DISTRIBUTION_WINDOW = 3600;

// Default age threshold for excluding stale unassigned conversations (7 days)
export const DEFAULT_EXCLUDE_OLDER_THAN_HOURS = 168;

// Options groupings
export const OPTIONS = {
  ORDER: [BALANCED, PRIORITY, SEQUENTIAL],
  PRIORITY: [EARLIEST_CREATED, LONGEST_WAITING],
};
