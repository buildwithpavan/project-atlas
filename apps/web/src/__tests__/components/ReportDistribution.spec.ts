import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import ReportDistribution from '@/components/reports/ReportDistribution.vue'

describe('ReportDistribution', () => {
  const distribution = { open: 40, closed: 30, pending: 10 }

  it('renders title', () => {
    const wrapper = mount(ReportDistribution, {
      props: { title: 'Status Distribution', distribution },
    })
    expect(wrapper.text()).toContain('Status Distribution')
  })

  it('renders labels and counts', () => {
    const wrapper = mount(ReportDistribution, {
      props: { title: 'Status', distribution },
    })
    expect(wrapper.text()).toContain('open')
    expect(wrapper.text()).toContain('40')
    expect(wrapper.text()).toContain('closed')
    expect(wrapper.text()).toContain('30')
  })

  it('sorts by count descending', () => {
    const wrapper = mount(ReportDistribution, {
      props: { title: 'Status', distribution },
    })
    const items = wrapper.findAll('[role="listitem"]')
    expect(items[0].text()).toContain('open')
    expect(items[1].text()).toContain('closed')
    expect(items[2].text()).toContain('pending')
  })

  it('renders progress bars with accessible labels', () => {
    const wrapper = mount(ReportDistribution, {
      props: { title: 'Status', distribution },
    })
    const bars = wrapper.findAll('[role="progressbar"]')
    expect(bars.length).toBe(3)
    expect(bars[0].attributes('aria-label')).toContain('open')
  })

  it('handles empty distribution', () => {
    const wrapper = mount(ReportDistribution, {
      props: { title: 'Status', distribution: {} },
    })
    expect(wrapper.text()).toContain('No data available')
  })

  it('shows loading skeleton', () => {
    const wrapper = mount(ReportDistribution, {
      props: { title: 'Status', distribution: {}, loading: true },
    })
    expect(wrapper.findAll('.animate-pulse').length).toBeGreaterThan(0)
  })
})
