<script setup lang="ts">
import { ref, onMounted } from 'vue'
import SidebarTree from './SidebarTree.vue'
import type { NavNode } from './SidebarTree.vue'

// ─── Raw JSON types ───────────────────────────────────────────────────────────

interface RawNavNode {
  title: string
  type: string
  path?: string          // absent on groupMarker nodes
  deprecated?: boolean
  children?: RawNavNode[]
}

interface NavigatorIndex {
  interfaceLanguages: Record<string, RawNavNode[]>
  schemaVersion: { major: number; minor: number; patch: number }
}

// ─── State ────────────────────────────────────────────────────────────────────

const navItems = ref<NavNode[]>([])
const loading = ref(false)
const loadFailed = ref(false)

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Returns the relative path from the current page back to the archive root.
 * e.g. /documentation/myframework/someclass → '../..'
 */
function archiveRoot(): string {
  const parts = window.location.pathname.split('/').filter(Boolean)
  return parts.length > 0 ? parts.map(() => '..').join('/') : '.'
}

/**
 * Recursively transform a RawNavNode into a NavNode.
 * groupMarker nodes become non-link section headers (no `path`).
 */
function transform(raw: RawNavNode): NavNode {
  return {
    title: raw.title,
    type: raw.type,
    path: raw.path,
    deprecated: raw.deprecated,
    children: raw.children?.map(transform),
  }
}

// ─── Data loading ─────────────────────────────────────────────────────────────

async function loadNavigator() {
  loading.value = true
  loadFailed.value = false
  try {
    const root = archiveRoot()
    const res = await fetch(`${root}/index/index.json`)
    if (!res.ok) throw new Error(`HTTP ${res.status}`)

    const data = await res.json() as NavigatorIndex

    // Prefer Swift, fall back to the first available language
    const langNodes =
      data.interfaceLanguages['swift'] ??
      Object.values(data.interfaceLanguages)[0] ??
      []

    navItems.value = langNodes.map(transform)
  } catch {
    loadFailed.value = true
    navItems.value = readBreadcrumbsFromDOM()
  } finally {
    loading.value = false
  }
}

/**
 * Fallback: read breadcrumb links already in the page DOM.
 */
function readBreadcrumbsFromDOM(): NavNode[] {
  const items: NavNode[] = []
  document.querySelectorAll<HTMLAnchorElement>('#breadcrumbs a').forEach((a) => {
    items.push({
      title: a.textContent?.trim() ?? '',
      path: a.getAttribute('href') ?? undefined,
      type: 'article',
    })
  })
  return items
}

onMounted(loadNavigator)
</script>

<template>
  <aside class="doc-sidebar" aria-label="Documentation navigator">
    <nav class="sidebar-nav">
      <p v-if="loading" class="sidebar-loading">Loading navigator…</p>

      <template v-else-if="navItems.length > 0">
        <p v-if="loadFailed" class="sidebar-empty">
          Showing page breadcrumbs (no navigator index found)
        </p>
        <SidebarTree :items="navItems" :depth="0" />
      </template>

      <p v-else class="sidebar-empty">No navigator available</p>
    </nav>
  </aside>
</template>
