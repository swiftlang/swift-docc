<script setup lang="ts">
import { ref, computed } from 'vue'

export interface NavNode {
  title: string
  type?: string
  path?: string        // absent on groupMarker nodes
  deprecated?: boolean
  children?: NavNode[]
}

const props = defineProps<{
  items: NavNode[]
  depth?: number
}>()

// Track which nodes are expanded (keyed by path)
const expanded = ref<Record<string, boolean>>({})

function toggle(path: string) {
  expanded.value[path] = !expanded.value[path]
}

function isExpanded(path: string) {
  return !!expanded.value[path]
}

const currentPath = computed(() => window.location.pathname)

function isActive(path: string) {
  return currentPath.value === path || currentPath.value.startsWith(path + '/')
}

function isGroupMarker(item: NavNode) {
  return item.type === 'groupMarker'
}
</script>

<template>
  <ul class="nav-tree" :style="depth && depth > 0 ? { paddingLeft: '16px' } : {}">
    <li
      v-for="(item, index) in items"
      :key="item.path ?? `${item.title}-${index}`"
      class="nav-tree-item"
    >
      <!-- Group marker: a non-link section header -->
      <span v-if="isGroupMarker(item)" class="nav-group-marker">
        {{ item.title }}
      </span>

      <!-- Regular node: expand button + link -->
      <template v-else>
        <div class="nav-item-row">
          <button
            v-if="item.children && item.children.length > 0 && item.path"
            class="nav-expand-btn"
            :class="{ expanded: isExpanded(item.path) }"
            :aria-expanded="isExpanded(item.path)"
            :aria-label="isExpanded(item.path) ? 'Collapse' : 'Expand'"
            @click.prevent="toggle(item.path!)"
          >
            ▶
          </button>
          <span v-else class="nav-expand-spacer" />

          <a
            v-if="item.path"
            :href="item.path"
            class="nav-link"
            :class="{ active: isActive(item.path), deprecated: item.deprecated }"
          >{{ item.title }}</a>
          <span v-else class="nav-link nav-link--no-path">{{ item.title }}</span>
        </div>

        <!-- Recursive children -->
        <SidebarTree
          v-if="item.children && item.children.length > 0 && item.path && isExpanded(item.path)"
          :items="item.children"
          :depth="(depth ?? 0) + 1"
        />
      </template>
    </li>
  </ul>
</template>

<style scoped>
.nav-tree {
  list-style: none;
  margin: 0;
  padding: 0;
}

.nav-group-marker {
  display: block;
  padding: 10px 12px 2px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--color-secondary-label, #6e6e73);
  user-select: none;
}

.nav-link.deprecated {
  text-decoration: line-through;
  opacity: 0.6;
}

.nav-link--no-path {
  cursor: default;
  color: var(--color-secondary-label, #6e6e73);
}
</style>
