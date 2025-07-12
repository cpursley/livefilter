/**
 * LiveFilter DateCalendarPosition Hook
 * 
 * This JavaScript hook is distributed as part of the LiveFilter Elixir library.
 * When LiveFilter is packaged, this file will be included in priv/static/js/hooks/
 * and users will install it via `mix live_filter.install.assets`.
 * 
 * Purpose: Handles positioning of date range calendar dropdowns to prevent viewport
 * overflow and maintains stable positioning during date selection.
 * 
 * Required by: LiveFilter.Components.DateRangeSelect
 * 
 * Usage in app.js:
 *   import DateCalendarPosition from "./hooks/live_filter/date_calendar_position"
 *   let hooks = { DateCalendarPosition }
 */

// Date Calendar Position Hook
// Handles positioning of date range calendar dropdowns to prevent viewport overflow
// and maintains stable positioning during date selection

const DateCalendarPosition = {
  mounted() {
    // Wait a tick to ensure DOM is ready
    requestAnimationFrame(() => {
      this.positionCalendar();
    });
    
    this.handleResize = () => {
      this.positionCalendar();
    };
    window.addEventListener('resize', this.handleResize);
  },
  
  beforeUpdate() {
    // Store current position before update to prevent jumping
    const content = this.el.querySelector('[data-calendar-content]');
    if (content && content.style.left) {
      this.storedPosition = {
        left: content.style.left,
        top: content.style.top
      };
    }
  },
  
  updated() {
    // Restore position after update to maintain stability
    if (this.storedPosition) {
      const content = this.el.querySelector('[data-calendar-content]');
      if (content) {
        content.style.left = this.storedPosition.left;
        content.style.top = this.storedPosition.top;
      }
    }
  },
  
  destroyed() {
    window.removeEventListener('resize', this.handleResize);
  },
  
  positionCalendar() {
    const wrapper = this.el.closest('[id$="-wrapper"]');
    if (!wrapper) return;
    
    const button = wrapper.querySelector('button');
    const content = this.el.querySelector('[data-calendar-content]');
    
    if (!button || !content) return;
    
    // Get button position
    const buttonRect = button.getBoundingClientRect();
    
    // Use fixed width for calculation (280px * 2 calendars + 1px divider + padding)
    const contentWidth = 600;
    
    // Calculate positions - default to left alignment
    let left = buttonRect.left;
    let top = buttonRect.bottom + 8; // 8px offset matches search selects
    
    // Check if it would overflow right edge
    if (left + contentWidth > window.innerWidth - 20) {
      // Align to right edge of button instead
      left = buttonRect.right - contentWidth;
    }
    
    // Ensure it doesn't go off left edge
    if (left < 20) {
      left = 20;
    }
    
    // Apply position
    content.style.left = `${left}px`;
    content.style.top = `${top}px`;
  }
};

export default DateCalendarPosition;