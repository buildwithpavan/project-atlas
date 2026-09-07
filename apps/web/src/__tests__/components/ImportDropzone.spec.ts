import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import ImportDropzone from '@/components/import/ImportDropzone.vue'

describe('ImportDropzone', () => {
  it('renders upload instruction text', () => {
    const wrapper = mount(ImportDropzone)
    expect(wrapper.text()).toContain('Drag and drop your CSV file here')
    expect(wrapper.text()).toContain('Choose CSV file')
    expect(wrapper.text()).toContain('CSV files only')
  })

  it('has accessible role and label', () => {
    const wrapper = mount(ImportDropzone)
    const zone = wrapper.find('[role="button"]')
    expect(zone.exists()).toBe(true)
    expect(zone.attributes('aria-label')).toContain('Upload area')
    expect(zone.attributes('tabindex')).toBe('0')
  })

  it('has an accessible file input', () => {
    const wrapper = mount(ImportDropzone)
    const input = wrapper.find('input[type="file"]')
    expect(input.exists()).toBe(true)
    expect(input.attributes('accept')).toBe('.csv')
    expect(input.attributes('aria-label')).toBeTruthy()
  })

  it('shows drag-active text on dragenter', async () => {
    const wrapper = mount(ImportDropzone)
    const zone = wrapper.find('[role="button"]')
    await zone.trigger('dragenter')
    expect(wrapper.text()).toContain('Drop your CSV file here')
  })

  it('resets drag state on dragleave', async () => {
    const wrapper = mount(ImportDropzone)
    const zone = wrapper.find('[role="button"]')
    await zone.trigger('dragenter')
    expect(wrapper.text()).toContain('Drop your CSV file here')
    await zone.trigger('dragleave')
    expect(wrapper.text()).toContain('Drag and drop your CSV file here')
  })

  it('emits select on drop with a file', async () => {
    const wrapper = mount(ImportDropzone)
    const zone = wrapper.find('[role="button"]')
    const file = new File(['data'], 'test.csv', { type: 'text/csv' })
    const dataTransfer = { files: [file] }
    await zone.trigger('drop', { dataTransfer })
    expect(wrapper.emitted('select')).toBeTruthy()
    expect(wrapper.emitted('select')![0]).toEqual([file])
  })

  it('emits select on file input change', async () => {
    const wrapper = mount(ImportDropzone)
    const input = wrapper.find('input[type="file"]')
    const file = new File(['data'], 'tickets.csv', { type: 'text/csv' })

    // Simulate file selection
    Object.defineProperty(input.element, 'files', {
      value: [file],
      writable: false,
    })
    await input.trigger('change')

    expect(wrapper.emitted('select')).toBeTruthy()
    expect(wrapper.emitted('select')![0]).toEqual([file])
  })

  it('opens file picker on keyboard enter', async () => {
    const wrapper = mount(ImportDropzone)
    const input = wrapper.find('input[type="file"]')
    const clickSpy = vi.spyOn(input.element as HTMLInputElement, 'click')
    const zone = wrapper.find('[role="button"]')
    await zone.trigger('keydown.enter')
    expect(clickSpy).toHaveBeenCalled()
  })

  it('applies disabled styles when disabled', () => {
    const wrapper = mount(ImportDropzone, { props: { disabled: true } })
    const zone = wrapper.find('[role="button"]')
    expect(zone.classes()).toContain('pointer-events-none')
  })
})
