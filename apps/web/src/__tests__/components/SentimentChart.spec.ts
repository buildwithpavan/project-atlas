import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import SentimentChart from '@/components/dashboard/SentimentChart.vue'

describe('SentimentChart', () => {
  const distribution = { positive: 40, neutral: 30, negative: 20 }

  it('renders sentiment labels and counts', () => {
    const wrapper = mount(SentimentChart, {
      props: { distribution },
    })
    expect(wrapper.text()).toContain('positive')
    expect(wrapper.text()).toContain('40')
    expect(wrapper.text()).toContain('neutral')
    expect(wrapper.text()).toContain('30')
    expect(wrapper.text()).toContain('negative')
    expect(wrapper.text()).toContain('20')
  })

  it('renders percentages', () => {
    const wrapper = mount(SentimentChart, {
      props: { distribution: { positive: 60, negative: 40 } },
    })
    expect(wrapper.text()).toContain('60%')
    expect(wrapper.text()).toContain('40%')
  })

  it('renders SVG donut chart', () => {
    const wrapper = mount(SentimentChart, {
      props: { distribution },
    })
    expect(wrapper.find('svg').exists()).toBe(true)
    // One background circle + one per segment
    const circles = wrapper.findAll('circle')
    expect(circles.length).toBe(4) // 1 bg + 3 segments
  })

  it('has accessible aria-label on SVG', () => {
    const wrapper = mount(SentimentChart, {
      props: { distribution },
    })
    const svg = wrapper.find('svg')
    expect(svg.attributes('aria-label')).toContain('positive')
    expect(svg.attributes('role')).toBe('img')
  })

  it('shows total in center', () => {
    const wrapper = mount(SentimentChart, {
      props: { distribution },
    })
    expect(wrapper.text()).toContain('90')
    expect(wrapper.text()).toContain('total')
  })

  it('handles empty distribution', () => {
    const wrapper = mount(SentimentChart, {
      props: { distribution: {} },
    })
    expect(wrapper.text()).toContain('No sentiment data')
    expect(wrapper.find('svg').exists()).toBe(false)
  })

  it('handles all-zero distribution', () => {
    const wrapper = mount(SentimentChart, {
      props: { distribution: { positive: 0, negative: 0 } },
    })
    expect(wrapper.text()).toContain('No sentiment data')
  })

  it('handles partial categories (missing neutral)', () => {
    const wrapper = mount(SentimentChart, {
      props: { distribution: { positive: 10 } },
    })
    expect(wrapper.text()).toContain('positive')
    expect(wrapper.text()).toContain('10')
    expect(wrapper.find('svg').exists()).toBe(true)
  })
})
