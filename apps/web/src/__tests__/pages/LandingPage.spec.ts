import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import LandingPage from '@/pages/LandingPage.vue'

vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/', name: 'landing', component: LandingPage, meta: { public: true, authRedirect: true } },
      { path: '/login', name: 'login', component: { template: '<div>Login</div>' } },
      { path: '/register', name: 'register', component: { template: '<div>Register</div>' } },
      { path: '/app/dashboard', name: 'dashboard', component: { template: '<div>Dashboard</div>' } },
    ],
  })
}

function mountLanding() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  router.push('/')

  return mount(LandingPage, {
    global: {
      plugins: [pinia, router],
    },
  })
}

describe('LandingPage', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('renders the landing page', () => {
    const wrapper = mountLanding()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays the hero heading', () => {
    const wrapper = mountLanding()
    const h1 = wrapper.find('h1')
    expect(h1.exists()).toBe(true)
    expect(h1.text()).toContain('Turn Customer Support Into')
    expect(h1.text()).toContain('Business Intelligence')
  })

  it('displays a product description', () => {
    const wrapper = mountLanding()
    const text = wrapper.text()
    expect(text).toContain('Voceive analyzes customer support conversations')
  })

  it('has Get Started CTA linking to /register', () => {
    const wrapper = mountLanding()
    const buttons = wrapper.findAll('button')
    const getStarted = buttons.find(b => b.text() === 'Get Started')
    expect(getStarted).toBeDefined()
  })

  it('has Sign In link to /login', () => {
    const wrapper = mountLanding()
    const links = wrapper.findAll('a')
    const signIn = links.find(a => a.text() === 'Sign In' && a.attributes('href') === '/login')
    expect(signIn).toBeDefined()
  })

  it('contains How It Works section', () => {
    const wrapper = mountLanding()
    const section = wrapper.find('#how-it-works')
    expect(section.exists()).toBe(true)
    expect(wrapper.text()).toContain('How Voceive works')
  })

  it('contains all six core capability sections', () => {
    const wrapper = mountLanding()
    const text = wrapper.text()
    expect(text).toContain('AI Ticket Analysis')
    expect(text).toContain('Customer Intelligence')
    expect(text).toContain('Dashboards & Reports')
    expect(text).toContain('Knowledge Base')
    expect(text).toContain('Ask Voceive')
    expect(text).toContain('Evidence-Backed Answers')
  })

  it('contains Ask Voceive section with example', () => {
    const wrapper = mountLanding()
    const text = wrapper.text()
    expect(text).toContain('Ask your support data')
    expect(text).toContain('What are customers struggling with most this month?')
    expect(text).toContain('Payment-related issues')
    expect(text).toContain('Sources')
  })

  it('contains closing CTA section', () => {
    const wrapper = mountLanding()
    const text = wrapper.text()
    expect(text).toContain('Understand what your customers are really saying')
  })

  it('contains a footer with copyright', () => {
    const wrapper = mountLanding()
    const footer = wrapper.find('footer')
    expect(footer.exists()).toBe(true)
    expect(footer.text()).toContain('Voceive')
    expect(footer.text()).toContain('All rights reserved')
  })

  it('has exactly one visible h1', () => {
    const wrapper = mountLanding()
    const h1s = wrapper.findAll('h1')
    // Filter out sr-only headings
    const visibleH1s = h1s.filter(h => !h.classes().includes('sr-only'))
    expect(visibleH1s).toHaveLength(1)
  })

  it('contains no Atlas branding', () => {
    const wrapper = mountLanding()
    const text = wrapper.text()
    expect(text).not.toContain('Atlas')
    expect(text).not.toContain('atlas')
    expect(text).not.toContain('Project Atlas')
  })

  it('has accessible navigation landmark', () => {
    const wrapper = mountLanding()
    const nav = wrapper.find('nav')
    expect(nav.exists()).toBe(true)
    expect(nav.attributes('aria-label')).toBeTruthy()
  })

  it('has main content landmark', () => {
    const wrapper = mountLanding()
    const main = wrapper.find('main')
    expect(main.exists()).toBe(true)
  })

  it('has header landmark', () => {
    const wrapper = mountLanding()
    const header = wrapper.find('header')
    expect(header.exists()).toBe(true)
  })

  it('has footer landmark', () => {
    const wrapper = mountLanding()
    const footer = wrapper.find('footer')
    expect(footer.exists()).toBe(true)
  })

  it('has a skip-to-content link', () => {
    const wrapper = mountLanding()
    const skipLink = wrapper.find('a[href="#main-content"]')
    expect(skipLink.exists()).toBe(true)
    expect(skipLink.text()).toContain('Skip to main content')
  })

  it('contains Who Voceive is for section', () => {
    const wrapper = mountLanding()
    const text = wrapper.text()
    expect(text).toContain('Who Voceive is for')
    expect(text).toContain('Support Leaders')
    expect(text).toContain('Product Teams')
    expect(text).toContain('Customer Success')
    expect(text).toContain('Engineering')
  })

  it('contains value/problem section', () => {
    const wrapper = mountLanding()
    const text = wrapper.text()
    expect(text).toContain('Your support team already has the answers')
  })

  it('contains How It Works three steps', () => {
    const wrapper = mountLanding()
    const text = wrapper.text()
    expect(text).toContain('Bring in your support data')
    expect(text).toContain('Let Voceive analyze it')
    expect(text).toContain('Ask questions and act')
  })

  it('Sign In footer link points to /login', () => {
    const wrapper = mountLanding()
    const footer = wrapper.find('footer')
    const links = footer.findAll('a')
    const signIn = links.find(a => a.text() === 'Sign In')
    expect(signIn).toBeDefined()
    expect(signIn!.attributes('href')).toBe('/login')
  })

  it('Get Started footer link points to /register', () => {
    const wrapper = mountLanding()
    const footer = wrapper.find('footer')
    const links = footer.findAll('a')
    const getStarted = links.find(a => a.text() === 'Get Started')
    expect(getStarted).toBeDefined()
    expect(getStarted!.attributes('href')).toBe('/register')
  })
})
