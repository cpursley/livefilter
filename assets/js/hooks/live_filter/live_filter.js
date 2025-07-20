/**
 * LiveFilter Unified Hook
 * 
 * A single hook that handles all JavaScript functionality for LiveFilter components.
 * This replaces individual component hooks for a cleaner API.
 * 
 * Usage in app.js:
 *   import LiveFilter from "./hooks/live_filter/live_filter"
 *   let hooks = { LiveFilter }
 */

const LiveFilter = {
  mounted() {
    // Detect which LiveFilter component this hook is attached to
    const component = this.el.dataset.livefilterComponent;
    
    if (!component) {
      console.warn("LiveFilter hook mounted on element without data-livefilter-component attribute");
      return;
    }
    
    // Initialize the appropriate component handler
    switch(component) {
      case 'date-range-select':
        this.initDateRangeSelect();
        break;
      // Future components can be added here
      // case 'search-select':
      //   this.initSearchSelect();
      //   break;
      default:
        console.warn(`Unknown LiveFilter component: ${component}`);
    }
  },
  
  // Date Range Select functionality (previously DateCalendarPosition)
  initDateRangeSelect() {
    // Set up resize handler
    this.handleResize = () => {
      this.positionDateCalendar();
    };
    
    // Wait a tick to ensure DOM is ready
    requestAnimationFrame(() => {
      this.positionDateCalendar();
    });
    
    window.addEventListener('resize', this.handleResize);
  },
  
  beforeUpdate() {
    const component = this.el.dataset.livefilterComponent;
    
    if (component === 'date-range-select') {
      // Store current position before update to prevent jumping
      const content = this.el.querySelector('[data-calendar-content]');
      if (content && content.style.left) {
        this.storedPosition = {
          left: content.style.left,
          top: content.style.top
        };
      }
    }
  },
  
  updated() {
    const component = this.el.dataset.livefilterComponent;
    
    if (component === 'date-range-select') {
      // Restore position after update to maintain stability
      if (this.storedPosition) {
        const content = this.el.querySelector('[data-calendar-content]');
        if (content) {
          content.style.left = this.storedPosition.left;
          content.style.top = this.storedPosition.top;
        }
      }
    }
  },
  
  destroyed() {
    const component = this.el.dataset.livefilterComponent;
    
    if (component === 'date-range-select' && this.handleResize) {
      window.removeEventListener('resize', this.handleResize);
    }
  },
  
  // Helper methods for date range select
  positionDateCalendar() {
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

export default LiveFilter;