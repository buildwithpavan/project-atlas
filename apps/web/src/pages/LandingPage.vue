<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { AButton, ALogo, ACard } from '@/components/ui'

const router = useRouter()

function scrollToSection(id: string) {
  const el = document.getElementById(id)
  if (el) {
    el.scrollIntoView({ behavior: 'smooth' })
  }
}

const currentYear = computed(() => new Date().getFullYear())

const capabilities = [
  {
    title: 'AI Ticket Analysis',
    description: 'Understand sentiment, categories, signals and important patterns across support conversations.',
    icon: 'analysis',
  },
  {
    title: 'Customer Intelligence',
    description: 'Surface recurring themes and issues across customer conversations.',
    icon: 'intelligence',
  },
  {
    title: 'Dashboards & Reports',
    description: 'Turn support activity into clear metrics, trends and executive-level summaries.',
    icon: 'dashboard',
  },
  {
    title: 'Knowledge Base',
    description: 'Bring internal documents and support knowledge into one searchable intelligence layer.',
    icon: 'knowledge',
  },
  {
    title: 'Ask Voceive',
    description: 'Ask questions about your customer support data and knowledge in natural language.',
    icon: 'ask',
  },
  {
    title: 'Evidence-Backed Answers',
    description: 'See the sources behind AI answers so teams can understand where insights came from.',
    icon: 'evidence',
  },
]

const steps = [
  {
    number: '1',
    title: 'Bring in your support data',
    description: 'Import customer support tickets via CSV. Voceive accepts conversations from any helpdesk or support platform.',
  },
  {
    number: '2',
    title: 'Let Voceive analyze it',
    description: 'AI processes every conversation — extracting sentiment, categories, themes and recurring patterns across your data.',
  },
  {
    number: '3',
    title: 'Ask questions and act',
    description: 'Explore dashboards, generate reports, search your knowledge base, or ask Voceive directly in natural language.',
  },
]

const personas = [
  {
    title: 'Support Leaders',
    points: [
      'Understand recurring customer problems',
      'Monitor sentiment and trends',
    ],
  },
  {
    title: 'Product Teams',
    points: [
      'Discover product pain points directly from customer conversations',
    ],
  },
  {
    title: 'Customer Success & Operations',
    points: [
      'Identify emerging issues and prioritize action',
    ],
  },
  {
    title: 'Engineering & Technical Teams',
    points: [
      'Surface recurring technical issues and supporting evidence',
    ],
  },
]
</script>

<template>
  <div class="min-h-screen bg-voceive-background">
    <!-- Skip to content -->
    <a
      href="#main-content"
      class="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-[100] focus:rounded-voceive focus:bg-voceive-brand focus:px-4 focus:py-2 focus:text-white focus:text-sm focus:font-medium"
    >
      Skip to main content
    </a>

    <!-- ==================== NAVBAR ==================== -->
    <header
      class="sticky top-0 z-50 border-b border-voceive-border bg-voceive-surface/95 backdrop-blur-sm"
    >
      <nav
        class="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6 lg:px-8"
        aria-label="Main navigation"
      >
        <RouterLink
          to="/"
          class="voceive-focus-ring rounded-voceive"
          aria-label="Voceive home"
        >
          <ALogo variant="full" height="28px" />
        </RouterLink>

        <div class="flex items-center gap-2 sm:gap-3">
          <RouterLink
            to="/login"
            class="voceive-focus-ring rounded-voceive px-3 py-1.5 text-sm font-medium text-voceive-text-secondary hover:text-voceive-text-primary transition-colors"
          >
            Sign In
          </RouterLink>
          <AButton
            variant="primary"
            size="sm"
            @click="router.push('/register')"
          >
            Get Started
          </AButton>
        </div>
      </nav>
    </header>

    <!-- ==================== MAIN ==================== -->
    <main id="main-content">

      <!-- ==================== HERO ==================== -->
      <section
        class="relative overflow-hidden px-4 pb-16 pt-16 sm:px-6 sm:pb-24 sm:pt-24 lg:px-8"
        aria-labelledby="hero-heading"
      >
        <div class="mx-auto max-w-6xl">
          <div class="grid grid-cols-1 items-center gap-12 lg:grid-cols-2 lg:gap-16">
            <!-- Copy -->
            <div class="text-center lg:text-left">
              <h1
                id="hero-heading"
                class="text-4xl font-bold tracking-tight text-voceive-text-primary sm:text-5xl"
                style="line-height: 1.15"
              >
                Turn Customer Support Into
                <span class="text-voceive-brand"> Business Intelligence</span>
              </h1>
              <p class="mt-6 text-lg text-voceive-text-secondary" style="line-height: 1.7">
                Voceive analyzes customer support conversations, surfaces patterns
                and sentiment, and lets your team ask questions about what customers
                are really saying.
              </p>
              <div class="mt-8 flex flex-col gap-3 sm:flex-row sm:justify-center lg:justify-start">
                <AButton
                  variant="primary"
                  size="lg"
                  @click="router.push('/register')"
                >
                  Get Started
                </AButton>
                <AButton
                  variant="secondary"
                  size="lg"
                  @click="scrollToSection('how-it-works')"
                >
                  See How It Works
                </AButton>
              </div>
            </div>

            <!-- Hero visual — CSS-based product intelligence flow -->
            <div
              class="relative mx-auto w-full max-w-lg lg:max-w-none"
              aria-hidden="true"
            >
              <div class="rounded-voceive-lg border border-voceive-border bg-voceive-surface p-5 shadow-voceive-md">
                <!-- Pipeline header -->
                <div class="mb-4 flex items-center gap-2">
                  <div class="size-2.5 rounded-voceive-full bg-voceive-success" />
                  <span class="text-xs font-medium text-voceive-text-muted">Intelligence Pipeline</span>
                </div>
                <!-- Flow stages -->
                <div class="space-y-3">
                  <!-- Stage 1: Support Data -->
                  <div class="flex items-center gap-3 rounded-voceive border border-voceive-border-subtle bg-voceive-surface-muted px-4 py-3">
                    <div class="flex size-8 shrink-0 items-center justify-center rounded-voceive bg-voceive-info-subtle">
                      <svg class="size-4 text-voceive-info" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                        <path d="M5.433 13.917l1.262-3.155A4 4 0 017.58 9.42l6.92-6.918a2.121 2.121 0 013 3l-6.92 6.918c-.383.383-.84.685-1.343.886l-3.154 1.262a.5.5 0 01-.65-.65z" />
                        <path d="M3.5 5.75c0-.69.56-1.25 1.25-1.25H10A.75.75 0 0010 3H4.75A2.75 2.75 0 002 5.75v9.5A2.75 2.75 0 004.75 18h9.5A2.75 2.75 0 0017 15.25V10a.75.75 0 00-1.5 0v5.25c0 .69-.56 1.25-1.25 1.25h-9.5c-.69 0-1.25-.56-1.25-1.25v-9.5z" />
                      </svg>
                    </div>
                    <div class="min-w-0 flex-1">
                      <p class="text-xs font-medium text-voceive-text-primary">Support Conversations</p>
                      <p class="text-xs text-voceive-text-muted">1,247 tickets imported</p>
                    </div>
                  </div>
                  <!-- Arrow -->
                  <div class="flex justify-center">
                    <svg class="size-5 text-voceive-text-disabled" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                      <path fill-rule="evenodd" d="M10 3a.75.75 0 01.75.75v10.638l3.96-4.158a.75.75 0 111.08 1.04l-5.25 5.5a.75.75 0 01-1.08 0l-5.25-5.5a.75.75 0 111.08-1.04l3.96 4.158V3.75A.75.75 0 0110 3z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <!-- Stage 2: AI Analysis -->
                  <div class="flex items-center gap-3 rounded-voceive border border-voceive-ai/20 bg-voceive-ai-subtle px-4 py-3">
                    <div class="flex size-8 shrink-0 items-center justify-center rounded-voceive bg-voceive-ai/10">
                      <svg class="size-4 text-voceive-ai" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                        <path d="M15.98 1.804a1 1 0 00-1.96 0l-.24 1.192a1 1 0 01-.784.785l-1.192.238a1 1 0 000 1.962l1.192.238a1 1 0 01.785.785l.238 1.192a1 1 0 001.962 0l.238-1.192a1 1 0 01.785-.785l1.192-.238a1 1 0 000-1.962l-1.192-.238a1 1 0 01-.785-.785l-.238-1.192zM6.949 5.684a1 1 0 00-1.898 0l-.683 2.051a1 1 0 01-.633.633l-2.052.683a1 1 0 000 1.898l2.052.683a1 1 0 01.633.633l.683 2.051a1 1 0 001.898 0l.683-2.051a1 1 0 01.633-.633l2.052-.683a1 1 0 000-1.898l-2.052-.683a1 1 0 01-.633-.633L6.95 5.684zM13.949 13.684a1 1 0 00-1.898 0l-.184.551a1 1 0 01-.632.633l-.551.183a1 1 0 000 1.898l.551.183a1 1 0 01.633.633l.183.551a1 1 0 001.898 0l.184-.551a1 1 0 01.632-.633l.551-.183a1 1 0 000-1.898l-.551-.184a1 1 0 01-.633-.632l-.183-.551z" />
                      </svg>
                    </div>
                    <div class="min-w-0 flex-1">
                      <p class="text-xs font-medium text-voceive-text-primary">AI Analysis</p>
                      <div class="mt-1 flex flex-wrap gap-1.5">
                        <span class="inline-flex items-center rounded-voceive-full bg-voceive-success-subtle px-2 py-0.5 text-[10px] font-medium text-voceive-success">Sentiment</span>
                        <span class="inline-flex items-center rounded-voceive-full bg-voceive-info-subtle px-2 py-0.5 text-[10px] font-medium text-voceive-info">Categories</span>
                        <span class="inline-flex items-center rounded-voceive-full bg-voceive-warning-subtle px-2 py-0.5 text-[10px] font-medium text-voceive-warning">Themes</span>
                        <span class="inline-flex items-center rounded-voceive-full bg-voceive-ai-subtle px-2 py-0.5 text-[10px] font-medium text-voceive-ai">Signals</span>
                      </div>
                    </div>
                  </div>
                  <!-- Arrow -->
                  <div class="flex justify-center">
                    <svg class="size-5 text-voceive-text-disabled" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                      <path fill-rule="evenodd" d="M10 3a.75.75 0 01.75.75v10.638l3.96-4.158a.75.75 0 111.08 1.04l-5.25 5.5a.75.75 0 01-1.08 0l-5.25-5.5a.75.75 0 111.08-1.04l3.96 4.158V3.75A.75.75 0 0110 3z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <!-- Stage 3: Intelligence Output -->
                  <div class="grid grid-cols-2 gap-2">
                    <div class="rounded-voceive border border-voceive-border-subtle bg-voceive-surface-muted px-3 py-2.5">
                      <p class="text-[10px] font-medium uppercase tracking-wider text-voceive-text-muted">Dashboards</p>
                      <p class="mt-0.5 text-sm font-semibold text-voceive-text-primary">Metrics &amp; Trends</p>
                    </div>
                    <div class="rounded-voceive border border-voceive-border-subtle bg-voceive-surface-muted px-3 py-2.5">
                      <p class="text-[10px] font-medium uppercase tracking-wider text-voceive-text-muted">Reports</p>
                      <p class="mt-0.5 text-sm font-semibold text-voceive-text-primary">Executive Summaries</p>
                    </div>
                    <div class="rounded-voceive border border-voceive-border-subtle bg-voceive-surface-muted px-3 py-2.5">
                      <p class="text-[10px] font-medium uppercase tracking-wider text-voceive-text-muted">Knowledge</p>
                      <p class="mt-0.5 text-sm font-semibold text-voceive-text-primary">Search &amp; Discover</p>
                    </div>
                    <div class="rounded-voceive border border-voceive-ai/20 bg-voceive-ai-subtle px-3 py-2.5">
                      <p class="text-[10px] font-medium uppercase tracking-wider text-voceive-ai">Ask Voceive</p>
                      <p class="mt-0.5 text-sm font-semibold text-voceive-text-primary">Natural Language</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- ==================== VALUE / PROBLEM ==================== -->
      <section
        class="border-t border-voceive-border bg-voceive-surface px-4 py-16 sm:px-6 sm:py-24 lg:px-8"
        aria-labelledby="value-heading"
      >
        <div class="mx-auto max-w-3xl text-center">
          <h2
            id="value-heading"
            class="text-2xl font-bold text-voceive-text-primary sm:text-3xl"
          >
            Your support team already has the answers
          </h2>
          <p class="mt-4 text-base text-voceive-text-secondary sm:text-lg" style="line-height: 1.7">
            They're buried in thousands of conversations. Recurring customer problems,
            shifting sentiment, product issues, emerging themes and knowledge gaps
            — the signals are there, but raw tickets are difficult to turn into
            business-level insight.
          </p>
          <p class="mt-4 text-base text-voceive-text-secondary sm:text-lg" style="line-height: 1.7">
            Voceive is the intelligence layer that makes sense of it all.
          </p>
        </div>
      </section>

      <!-- ==================== CORE CAPABILITIES ==================== -->
      <section
        class="border-t border-voceive-border px-4 py-16 sm:px-6 sm:py-24 lg:px-8"
        aria-labelledby="capabilities-heading"
      >
        <div class="mx-auto max-w-6xl">
          <div class="text-center">
            <h2
              id="capabilities-heading"
              class="text-2xl font-bold text-voceive-text-primary sm:text-3xl"
            >
              What Voceive does
            </h2>
            <p class="mt-3 text-base text-voceive-text-secondary sm:text-lg">
              A complete intelligence platform for customer support data.
            </p>
          </div>

          <div class="mt-12 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <ACard
              v-for="cap in capabilities"
              :key="cap.title"
            >
              <!-- Icons -->
              <div class="mb-4 flex size-10 items-center justify-center rounded-voceive-md bg-voceive-brand-subtle">
                <!-- AI Ticket Analysis -->
                <svg v-if="cap.icon === 'analysis'" class="size-5 text-voceive-brand" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path d="M15.98 1.804a1 1 0 00-1.96 0l-.24 1.192a1 1 0 01-.784.785l-1.192.238a1 1 0 000 1.962l1.192.238a1 1 0 01.785.785l.238 1.192a1 1 0 001.962 0l.238-1.192a1 1 0 01.785-.785l1.192-.238a1 1 0 000-1.962l-1.192-.238a1 1 0 01-.785-.785l-.238-1.192zM6.949 5.684a1 1 0 00-1.898 0l-.683 2.051a1 1 0 01-.633.633l-2.052.683a1 1 0 000 1.898l2.052.683a1 1 0 01.633.633l.683 2.051a1 1 0 001.898 0l.683-2.051a1 1 0 01.633-.633l2.052-.683a1 1 0 000-1.898l-2.052-.683a1 1 0 01-.633-.633L6.95 5.684z" />
                </svg>
                <!-- Customer Intelligence -->
                <svg v-else-if="cap.icon === 'intelligence'" class="size-5 text-voceive-brand" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z" clip-rule="evenodd" />
                </svg>
                <!-- Dashboards & Reports -->
                <svg v-else-if="cap.icon === 'dashboard'" class="size-5 text-voceive-brand" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path d="M15.5 2A1.5 1.5 0 0014 3.5v13a1.5 1.5 0 001.5 1.5h1a1.5 1.5 0 001.5-1.5v-13A1.5 1.5 0 0016.5 2h-1zM9.5 6A1.5 1.5 0 008 7.5v9A1.5 1.5 0 009.5 18h1a1.5 1.5 0 001.5-1.5v-9A1.5 1.5 0 0010.5 6h-1zM3.5 10A1.5 1.5 0 002 11.5v5A1.5 1.5 0 003.5 18h1A1.5 1.5 0 006 16.5v-5A1.5 1.5 0 004.5 10h-1z" />
                </svg>
                <!-- Knowledge Base -->
                <svg v-else-if="cap.icon === 'knowledge'" class="size-5 text-voceive-brand" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path d="M10.75 16.82A7.462 7.462 0 0115 15.5c.71 0 1.396.098 2.046.282A.75.75 0 0018 15.06v-11a.75.75 0 00-.546-.721A9.006 9.006 0 0015 3a8.999 8.999 0 00-4.25 1.065V16.82zM9.25 4.065A8.999 8.999 0 005 3c-.85 0-1.673.118-2.454.339A.75.75 0 002 4.06v11a.75.75 0 00.954.721A7.506 7.506 0 015 15.5c1.579 0 3.042.487 4.25 1.32V4.065z" />
                </svg>
                <!-- Ask Voceive -->
                <svg v-else-if="cap.icon === 'ask'" class="size-5 text-voceive-brand" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M10 2c-2.236 0-4.43.18-6.57.524C1.993 2.755 1 3.97 1 5.35v5.3c0 1.38.993 2.595 2.43 2.826 1.14.184 2.302.33 3.48.424l2.674 2.394A.75.75 0 0010.85 15.7v-1.574c1.453-.123 2.878-.32 4.27-.582C16.507 13.246 17.5 12.03 17.5 10.65V5.35c0-1.38-.993-2.595-2.43-2.826A41.645 41.645 0 0010 2z" clip-rule="evenodd" />
                </svg>
                <!-- Evidence-Backed -->
                <svg v-else-if="cap.icon === 'evidence'" class="size-5 text-voceive-brand" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M16.403 12.652a3 3 0 000-5.304 3 3 0 00-3.75-3.751 3 3 0 00-5.305 0 3 3 0 00-3.751 3.75 3 3 0 000 5.305 3 3 0 003.75 3.751 3 3 0 005.305 0 3 3 0 003.751-3.75zm-2.546-4.46a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
                </svg>
              </div>

              <h3 class="text-base font-semibold text-voceive-text-primary">
                {{ cap.title }}
              </h3>
              <p class="mt-2 text-sm text-voceive-text-secondary" style="line-height: 1.6">
                {{ cap.description }}
              </p>
            </ACard>
          </div>
        </div>
      </section>

      <!-- ==================== HOW IT WORKS ==================== -->
      <section
        id="how-it-works"
        class="scroll-mt-20 border-t border-voceive-border bg-voceive-surface px-4 py-16 sm:px-6 sm:py-24 lg:px-8"
        aria-labelledby="how-heading"
      >
        <div class="mx-auto max-w-4xl">
          <div class="text-center">
            <h2
              id="how-heading"
              class="text-2xl font-bold text-voceive-text-primary sm:text-3xl"
            >
              How Voceive works
            </h2>
            <p class="mt-3 text-base text-voceive-text-secondary sm:text-lg">
              From raw support conversations to actionable intelligence in three steps.
            </p>
          </div>

          <div class="mt-12">
            <!-- Steps -->
            <div class="relative">
              <!-- Connecting line (desktop) -->
              <div class="absolute left-6 top-6 hidden h-[calc(100%-48px)] w-px bg-voceive-border lg:left-1/2 lg:-ml-px lg:block" aria-hidden="true" />

              <div class="space-y-8 lg:space-y-12">
                <div
                  v-for="(step, index) in steps"
                  :key="step.number"
                  class="relative flex flex-col items-center gap-4 lg:flex-row"
                  :class="index % 2 === 0 ? 'lg:flex-row' : 'lg:flex-row-reverse'"
                >
                  <!-- Step content -->
                  <div class="flex-1 text-center lg:text-left" :class="index % 2 !== 0 ? 'lg:text-right' : ''">
                    <div class="rounded-voceive-lg border border-voceive-border bg-voceive-background p-5">
                      <p class="text-xs font-semibold uppercase tracking-wider text-voceive-brand">
                        Step {{ step.number }}
                      </p>
                      <h3 class="mt-2 text-lg font-semibold text-voceive-text-primary">
                        {{ step.title }}
                      </h3>
                      <p class="mt-2 text-sm text-voceive-text-secondary" style="line-height: 1.6">
                        {{ step.description }}
                      </p>
                    </div>
                  </div>
                  <!-- Step number badge -->
                  <div
                    class="order-first flex size-12 shrink-0 items-center justify-center rounded-voceive-full border-2 border-voceive-brand bg-voceive-surface text-sm font-bold text-voceive-brand lg:order-none"
                  >
                    {{ step.number }}
                  </div>
                  <!-- Spacer for alternating layout -->
                  <div class="hidden flex-1 lg:block" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- ==================== ASK VOCEIVE ==================== -->
      <section
        class="border-t border-voceive-border px-4 py-16 sm:px-6 sm:py-24 lg:px-8"
        aria-labelledby="ask-heading"
      >
        <div class="mx-auto max-w-6xl">
          <div class="grid grid-cols-1 items-center gap-12 lg:grid-cols-2 lg:gap-16">
            <!-- Copy -->
            <div>
              <h2
                id="ask-heading"
                class="text-2xl font-bold text-voceive-text-primary sm:text-3xl"
              >
                Ask your support data
              </h2>
              <p class="mt-4 text-base text-voceive-text-secondary sm:text-lg" style="line-height: 1.7">
                Ask questions in natural language and receive AI-generated answers
                grounded in your support conversations and uploaded knowledge documents.
                Every response includes the sources it drew from, so your team
                can verify and trust the insights.
              </p>
              <ul class="mt-6 space-y-3">
                <li class="flex items-start gap-3">
                  <svg class="mt-0.5 size-5 shrink-0 text-voceive-success" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                  </svg>
                  <span class="text-sm text-voceive-text-secondary">Multi-turn conversations with context</span>
                </li>
                <li class="flex items-start gap-3">
                  <svg class="mt-0.5 size-5 shrink-0 text-voceive-success" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                  </svg>
                  <span class="text-sm text-voceive-text-secondary">Evidence-backed responses with cited sources</span>
                </li>
                <li class="flex items-start gap-3">
                  <svg class="mt-0.5 size-5 shrink-0 text-voceive-success" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                  </svg>
                  <span class="text-sm text-voceive-text-secondary">AI usage and quota visibility</span>
                </li>
              </ul>
            </div>

            <!-- Example conversation -->
            <div class="mx-auto w-full max-w-md lg:max-w-none">
              <div class="rounded-voceive-lg border border-voceive-border bg-voceive-surface shadow-voceive-md">
                <!-- Header -->
                <div class="flex items-center gap-2 border-b border-voceive-border px-5 py-3">
                  <div class="flex size-6 items-center justify-center rounded-voceive-full bg-voceive-ai-subtle">
                    <svg class="size-3.5 text-voceive-ai" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                      <path fill-rule="evenodd" d="M10 2c-2.236 0-4.43.18-6.57.524C1.993 2.755 1 3.97 1 5.35v5.3c0 1.38.993 2.595 2.43 2.826 1.14.184 2.302.33 3.48.424l2.674 2.394A.75.75 0 0010.85 15.7v-1.574c1.453-.123 2.878-.32 4.27-.582C16.507 13.246 17.5 12.03 17.5 10.65V5.35c0-1.38-.993-2.595-2.43-2.826A41.645 41.645 0 0010 2z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <span class="text-sm font-medium text-voceive-text-primary">Ask Voceive</span>
                  <span class="ml-auto text-[10px] text-voceive-text-muted">Representative example</span>
                </div>
                <!-- Messages -->
                <div class="space-y-4 p-5">
                  <!-- User message -->
                  <div class="flex justify-end">
                    <div class="max-w-[85%] rounded-voceive-lg bg-voceive-brand px-4 py-2.5 text-sm text-white">
                      What are customers struggling with most this month?
                    </div>
                  </div>
                  <!-- AI response -->
                  <div>
                    <div class="max-w-[85%] rounded-voceive-lg border border-voceive-border bg-voceive-surface-muted px-4 py-3 text-sm text-voceive-text-primary" style="line-height: 1.6">
                      Payment-related issues are emerging as a recurring theme this month, appearing across multiple customer conversations with predominantly negative sentiment. Login and authentication problems are the second most reported category.
                    </div>
                    <!-- Sources -->
                    <div class="mt-2 max-w-[85%]">
                      <p class="text-[10px] font-medium uppercase tracking-wider text-voceive-text-muted">Sources</p>
                      <div class="mt-1 flex flex-wrap gap-1.5">
                        <span class="inline-flex items-center rounded-voceive bg-voceive-surface-muted px-2 py-0.5 text-[10px] text-voceive-text-secondary">
                          Payment Troubleshooting Guide
                        </span>
                        <span class="inline-flex items-center rounded-voceive bg-voceive-surface-muted px-2 py-0.5 text-[10px] text-voceive-text-secondary">
                          Customer conversations
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- ==================== WHO IT'S FOR ==================== -->
      <section
        class="border-t border-voceive-border bg-voceive-surface px-4 py-16 sm:px-6 sm:py-24 lg:px-8"
        aria-labelledby="personas-heading"
      >
        <div class="mx-auto max-w-6xl">
          <div class="text-center">
            <h2
              id="personas-heading"
              class="text-2xl font-bold text-voceive-text-primary sm:text-3xl"
            >
              Who Voceive is for
            </h2>
            <p class="mt-3 text-base text-voceive-text-secondary sm:text-lg">
              Built for every team that cares about what customers are saying.
            </p>
          </div>

          <div class="mt-12 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
            <div
              v-for="persona in personas"
              :key="persona.title"
              class="rounded-voceive-lg border border-voceive-border bg-voceive-background p-5"
            >
              <h3 class="text-sm font-semibold text-voceive-text-primary">
                {{ persona.title }}
              </h3>
              <ul class="mt-3 space-y-2">
                <li
                  v-for="(point, i) in persona.points"
                  :key="i"
                  class="flex items-start gap-2 text-sm text-voceive-text-secondary"
                >
                  <svg class="mt-1 size-3.5 shrink-0 text-voceive-brand" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" clip-rule="evenodd" />
                  </svg>
                  <span style="line-height: 1.5">{{ point }}</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <!-- ==================== CLOSING CTA ==================== -->
      <section
        class="border-t border-voceive-border px-4 py-16 sm:px-6 sm:py-24 lg:px-8"
        aria-labelledby="cta-heading"
      >
        <div class="mx-auto max-w-2xl text-center">
          <h2
            id="cta-heading"
            class="text-2xl font-bold text-voceive-text-primary sm:text-3xl"
          >
            Understand what your customers are really saying
          </h2>
          <p class="mt-4 text-base text-voceive-text-secondary sm:text-lg" style="line-height: 1.7">
            Bring your support data together, uncover the patterns behind it,
            and ask questions with Voceive.
          </p>
          <div class="mt-8 flex flex-col gap-3 sm:flex-row sm:justify-center">
            <AButton
              variant="primary"
              size="lg"
              @click="router.push('/register')"
            >
              Get Started
            </AButton>
            <AButton
              variant="secondary"
              size="lg"
              @click="router.push('/login')"
            >
              Sign In
            </AButton>
          </div>
        </div>
      </section>
    </main>

    <!-- ==================== FOOTER ==================== -->
    <footer class="border-t border-voceive-border bg-voceive-surface px-4 py-10 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-6xl">
        <div class="flex flex-col items-center gap-6 sm:flex-row sm:justify-between">
          <div class="flex flex-col items-center gap-2 sm:items-start">
            <ALogo variant="full" height="24px" />
            <p class="text-xs text-voceive-text-muted">
              AI-powered customer support intelligence.
            </p>
          </div>
          <div class="flex items-center gap-4">
            <RouterLink
              to="/login"
              class="voceive-focus-ring rounded-voceive text-sm text-voceive-text-secondary hover:text-voceive-text-primary transition-colors"
            >
              Sign In
            </RouterLink>
            <RouterLink
              to="/register"
              class="voceive-focus-ring rounded-voceive text-sm text-voceive-text-secondary hover:text-voceive-text-primary transition-colors"
            >
              Get Started
            </RouterLink>
          </div>
        </div>
        <div class="mt-8 border-t border-voceive-border pt-6 text-center sm:text-left">
          <p class="text-xs text-voceive-text-muted">
            &copy; {{ currentYear }} Voceive. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  </div>
</template>
