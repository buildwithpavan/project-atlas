import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import CategoryChart from '@/components/dashboard/CategoryChart.vue'

describe('CategoryChart', () => {
  const categories = { billing: 30, shipping: 20, login: 15, returns: 10 }

  it('renders category names and counts', () => {
    const wrapper = mount(CategoryChart, {
      props: { categories },
    })
    expect(wrapper.text()).toContain('billing')
    expect(wrapper.text()).toContain('30')
    expect(wrapper.text()).toContain('shipping')
    expect(wrapper.text()).toContain('20')
  })

  it('sorts categories by count descending', () => {
    const wrapper = mount(CategoryChart, {
      props: { categories },
    })
    const items = wrapper.findAll('[role="listitem"]')
    expect(items[0].text()).toContain('billing')
    expect(items[1].text()).toContain('shipping')
  })

  it('renders progress bars', () => {
    const wrapper = mount(CategoryChart, {
      props: { categories },
    })
    const bars = wrapper.findAll('[role="progressbar"]')
    expect(bars.length).toBe(4)
  })

  it('has accessible labels on bars', () => {
    const wrapper = mount(CategoryChart, {
      props: { categories },
    })
    const bar = wrapper.find('[role="progressbar"]')
    expect(bar.attributes('aria-label')).toContain('billing')
    expect(bar.attributes('aria-label')).toContain('30')
  })

  it('handles empty categories', () => {
    const wrapper = mount(CategoryChart, {
      props: { categories: {} },
    })
    expect(wrapper.text()).toContain('No category data')
    expect(wrapper.findAll('[role="listitem"]').length).toBe(0)
  })

  it('limits to 8 categories', () => {
    const many: Record<string, number> = {}
    for (let i = 0; i < 12; i++) {
      many[`cat-${i}`] = 12 - i
    }
    const wrapper = mount(CategoryChart, {
      props: { categories: many },
    })
    expect(wrapper.findAll('[role="listitem"]').length).toBe(8)
  })
})
