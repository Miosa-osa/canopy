/**
 * file-tree — foundation primitive for rendering a workspace's filesystem.
 *
 * Single source of truth for tree rendering. Both the /files project explorer
 * and the Build rail's ProjectExplorerSection import from this module.
 *
 * NOT a duplicate of `$lib/design/patterns/FileTreeNode.svelte` (the older,
 * fully-prefetched recursive renderer). This primitive lazy-loads children
 * via `directoryListingQuery` so opening a deep workspace stays instant.
 */
export { default as FileTree } from "./FileTree.svelte";
export { default as FileTreeNode } from "./FileTreeNode.svelte";
