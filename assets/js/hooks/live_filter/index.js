/**
 * LiveFilter JavaScript Hooks
 * 
 * Main entry point for LiveFilter JavaScript functionality.
 * Export the unified LiveFilter hook for use in Phoenix applications.
 */

import LiveFilter from './live_filter.js';

// For backward compatibility, also export the old hook name
import DateCalendarPosition from './date_calendar_position.js';

export default LiveFilter;
export { LiveFilter, DateCalendarPosition };