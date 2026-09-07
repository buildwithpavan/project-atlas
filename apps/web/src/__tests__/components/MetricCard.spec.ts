import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import MetricCard from '@/components/dashboard/MetricCard.vue'

describe('MetricCard', () => {
  it('renders label and value', () => {
    const wrapper = mount(MetricCard, {
      props: { label: 'Total Tickets', value: 42 },
    })
    expect(wrapper.text()).toContain('Total Tickets')
    expect(wrapper.text()).toContain('42')
  })

  it('renders description when provided', () => {
    const wrapper = mount(MetricCard, {
      props: { label: 'Total', value: 10, description: 'All collected' },
    })
    expect(wrapper.text()).toContain('All collected')
  })

  it('shows loading skeleton when loading', () => {
    const wrapper = mount(MetricCard, {
      props: { label: 'Total', value: 0, loading: true },
    })
    expect(wrapper.findAll('.animate-pulse').length).toBeGreaterThan(0)
    // Value should not be rendered
    expect(wrapper.find('.text-3xl').exists()).toBe(false)
  })

  it('renders string values', () => {
    const wrapper = mount(MetricCard, {
      props: { label: 'Status', value: 'Active' },
    })
    expect(wrapper.text()).toContain('Active')
  })

  it('renders zero value without breaking', () => {
    const wrapper = mount(MetricCard, {
      props: { label: 'Bugs', value: 0 },
    })
    expect(wrapper.text()).toContain('0')
  })
})
