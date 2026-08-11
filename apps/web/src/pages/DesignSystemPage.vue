<script setup lang="ts">
import { ref } from 'vue'
import { AButton, ACard, ABadge, AInput, ASelect, ATable } from '@/components/ui'

const inputValue = ref('')
const selectValue = ref('')

const selectOptions = [
  { value: 'open', label: 'Open' },
  { value: 'closed', label: 'Closed' },
  { value: 'pending', label: 'Pending' },
]

const tableColumns = [
  { key: 'id', label: 'ID' },
  { key: 'subject', label: 'Subject' },
  { key: 'status', label: 'Status' },
  { key: 'sentiment', label: 'Sentiment' },
]

const tableRows = [
  { id: '001', subject: 'Login not working', status: 'Open', sentiment: 'Negative' },
  { id: '002', subject: 'Feature request: dark mode', status: 'Pending', sentiment: 'Neutral' },
  { id: '003', subject: 'Great onboarding experience', status: 'Closed', sentiment: 'Positive' },
]
</script>

<template>
  <div class="min-h-screen bg-atlas-background">
    <header class="bg-atlas-surface border-b border-atlas-border px-6 py-4">
      <div class="mx-auto max-w-5xl flex items-center justify-between">
        <h1 class="text-xl font-bold text-atlas-brand">
          Atlas Design System
        </h1>
        <RouterLink
          to="/"
          class="text-sm text-atlas-text-secondary hover:text-atlas-text-primary transition-colors"
        >
          ← Home
        </RouterLink>
      </div>
    </header>

    <main class="mx-auto max-w-5xl px-6 py-8 space-y-12">
      <!-- COLORS -->
      <section>
        <h2 class="text-2xl font-semibold text-atlas-text-primary mb-6">
          Colors
        </h2>

        <h3 class="text-lg font-medium text-atlas-text-primary mb-3">
          Brand
        </h3>
        <div class="flex flex-wrap gap-3 mb-6">
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-brand" />
            <span class="text-xs text-atlas-text-muted">brand</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-brand-hover" />
            <span class="text-xs text-atlas-text-muted">hover</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-brand-active" />
            <span class="text-xs text-atlas-text-muted">active</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-brand-subtle border border-atlas-border-subtle" />
            <span class="text-xs text-atlas-text-muted">subtle</span>
          </div>
        </div>

        <h3 class="text-lg font-medium text-atlas-text-primary mb-3">
          Accent
        </h3>
        <div class="flex flex-wrap gap-3 mb-6">
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-accent" />
            <span class="text-xs text-atlas-text-muted">accent</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-accent-hover" />
            <span class="text-xs text-atlas-text-muted">hover</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-accent-subtle border border-atlas-border-subtle" />
            <span class="text-xs text-atlas-text-muted">subtle</span>
          </div>
        </div>

        <h3 class="text-lg font-medium text-atlas-text-primary mb-3">
          AI
        </h3>
        <div class="flex flex-wrap gap-3 mb-6">
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-ai" />
            <span class="text-xs text-atlas-text-muted">ai</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-ai-subtle border border-atlas-border-subtle" />
            <span class="text-xs text-atlas-text-muted">subtle</span>
          </div>
        </div>

        <h3 class="text-lg font-medium text-atlas-text-primary mb-3">
          Semantic
        </h3>
        <div class="flex flex-wrap gap-3 mb-6">
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-success" />
            <span class="text-xs text-atlas-text-muted">success</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-success-subtle border border-atlas-border-subtle" />
            <span class="text-xs text-atlas-text-muted">subtle</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-warning" />
            <span class="text-xs text-atlas-text-muted">warning</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-warning-subtle border border-atlas-border-subtle" />
            <span class="text-xs text-atlas-text-muted">subtle</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-error" />
            <span class="text-xs text-atlas-text-muted">error</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-error-subtle border border-atlas-border-subtle" />
            <span class="text-xs text-atlas-text-muted">subtle</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-info" />
            <span class="text-xs text-atlas-text-muted">info</span>
          </div>
          <div class="flex flex-col items-center gap-1.5">
            <div class="size-14 rounded-atlas-md bg-atlas-info-subtle border border-atlas-border-subtle" />
            <span class="text-xs text-atlas-text-muted">subtle</span>
          </div>
        </div>

        <h3 class="text-lg font-medium text-atlas-text-primary mb-3">
          Chart Palette
        </h3>
        <div class="flex flex-wrap gap-3">
          <div
            v-for="n in 8"
            :key="n"
            class="flex flex-col items-center gap-1.5"
          >
            <div
              class="size-14 rounded-atlas-md"
              :class="`bg-atlas-chart-${n}`"
            />
            <span class="text-xs text-atlas-text-muted">chart-{{ n }}</span>
          </div>
        </div>
      </section>

      <!-- TYPOGRAPHY -->
      <section>
        <h2 class="text-2xl font-semibold text-atlas-text-primary mb-6">
          Typography
        </h2>
        <ACard>
          <div class="space-y-4">
            <div>
              <span class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">Page title</span>
              <p class="text-3xl font-bold text-atlas-text-primary leading-tight">
                Dashboard Overview
              </p>
            </div>
            <div>
              <span class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">Section title</span>
              <p class="text-2xl font-semibold text-atlas-text-primary leading-tight">
                Ticket Analysis
              </p>
            </div>
            <div>
              <span class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">Card title</span>
              <p class="text-lg font-semibold text-atlas-text-primary">
                Sentiment Distribution
              </p>
            </div>
            <div>
              <span class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">Body</span>
              <p class="text-base text-atlas-text-primary">
                This is body text used for primary content throughout the application.
              </p>
            </div>
            <div>
              <span class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">Secondary / muted</span>
              <p class="text-sm text-atlas-text-secondary">
                Secondary text provides supplementary information.
              </p>
            </div>
            <div>
              <span class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">Label</span>
              <p class="text-sm font-medium text-atlas-text-primary">
                Form label
              </p>
            </div>
            <div>
              <span class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">Caption</span>
              <p class="text-xs text-atlas-text-muted">
                Last updated 5 minutes ago
              </p>
            </div>
            <div>
              <span class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">Dashboard metric</span>
              <p class="text-3xl font-bold tabular-nums text-atlas-text-primary">
                2,847
              </p>
            </div>
          </div>
        </ACard>
      </section>

      <!-- BUTTONS -->
      <section>
        <h2 class="text-2xl font-semibold text-atlas-text-primary mb-6">
          Buttons
        </h2>
        <ACard>
          <div class="space-y-4">
            <div class="flex flex-wrap items-center gap-3">
              <AButton variant="primary">
                Primary
              </AButton>
              <AButton variant="secondary">
                Secondary
              </AButton>
              <AButton variant="ghost">
                Ghost
              </AButton>
              <AButton variant="danger">
                Danger
              </AButton>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <AButton size="sm">
                Small
              </AButton>
              <AButton size="md">
                Medium
              </AButton>
              <AButton size="lg">
                Large
              </AButton>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <AButton disabled>
                Disabled
              </AButton>
              <AButton loading>
                Loading
              </AButton>
            </div>
          </div>
        </ACard>
      </section>

      <!-- BADGES -->
      <section>
        <h2 class="text-2xl font-semibold text-atlas-text-primary mb-6">
          Badges
        </h2>
        <ACard>
          <div class="flex flex-wrap gap-3">
            <ABadge>Default</ABadge>
            <ABadge variant="success">
              Success
            </ABadge>
            <ABadge variant="warning">
              Warning
            </ABadge>
            <ABadge variant="error">
              Error
            </ABadge>
            <ABadge variant="info">
              Info
            </ABadge>
            <ABadge variant="ai">
              AI Analysis
            </ABadge>
          </div>
        </ACard>
      </section>

      <!-- INPUTS -->
      <section>
        <h2 class="text-2xl font-semibold text-atlas-text-primary mb-6">
          Inputs
        </h2>
        <ACard>
          <div class="grid gap-4 sm:grid-cols-2">
            <AInput
              v-model="inputValue"
              label="Email address"
              placeholder="user@example.com"
              type="email"
            />
            <AInput
              model-value=""
              label="With error"
              placeholder="Invalid input"
              error="This field is required"
            />
            <ASelect
              v-model="selectValue"
              label="Status"
              placeholder="Select a status..."
              :options="selectOptions"
            />
            <AInput
              model-value=""
              label="Disabled"
              placeholder="Cannot edit"
              disabled
            />
          </div>
        </ACard>
      </section>

      <!-- TABLE -->
      <section>
        <h2 class="text-2xl font-semibold text-atlas-text-primary mb-6">
          Table
        </h2>
        <ATable
          :columns="tableColumns"
          :rows="tableRows"
        >
          <template #cell-status="{ value }">
            <ABadge
              :variant="
                value === 'Open' ? 'error'
                : value === 'Pending' ? 'warning'
                  : 'success'
              "
            >
              {{ value }}
            </ABadge>
          </template>
          <template #cell-sentiment="{ value }">
            <ABadge
              :variant="
                value === 'Negative' ? 'error'
                : value === 'Positive' ? 'success'
                  : 'default'
              "
            >
              {{ value }}
            </ABadge>
          </template>
        </ATable>
      </section>

      <!-- SHADOWS & RADIUS -->
      <section>
        <h2 class="text-2xl font-semibold text-atlas-text-primary mb-6">
          Shadows & Radius
        </h2>
        <div class="grid gap-6 sm:grid-cols-4">
          <div class="flex flex-col items-center gap-2">
            <div class="size-20 rounded-atlas-sm bg-atlas-surface shadow-atlas-sm" />
            <span class="text-xs text-atlas-text-muted">shadow-sm</span>
          </div>
          <div class="flex flex-col items-center gap-2">
            <div class="size-20 rounded-atlas bg-atlas-surface shadow-atlas" />
            <span class="text-xs text-atlas-text-muted">shadow</span>
          </div>
          <div class="flex flex-col items-center gap-2">
            <div class="size-20 rounded-atlas-md bg-atlas-surface shadow-atlas-md" />
            <span class="text-xs text-atlas-text-muted">shadow-md</span>
          </div>
          <div class="flex flex-col items-center gap-2">
            <div class="size-20 rounded-atlas-lg bg-atlas-surface shadow-atlas-lg" />
            <span class="text-xs text-atlas-text-muted">shadow-lg</span>
          </div>
        </div>
      </section>
    </main>
  </div>
</template>
