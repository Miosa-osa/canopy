<script lang="ts">
/**
 * MediaViewer — native <video> / <audio>.
 * CSS prefix: medvw- (Media Viewer).
 *
 * Mirrors the audio / video render branches in FilePreview.svelte. No new
 * playback library — the browser's native controls do the work.
 */

interface Props {
  /** Direct URL or blob URL for the media. */
  src: string;
  /** "audio" or "video". */
  kind: 'audio' | 'video';
  /** Accessible label. */
  label: string;
}

let { src, kind, label }: Props = $props();
</script>

<div class="medvw-root" aria-label={label}>
  {#if kind === "video"}
    <!-- svelte-ignore a11y_media_has_caption -->
    <video class="medvw-video" controls {src} aria-label={label}></video>
  {:else}
    <audio class="medvw-audio" controls {src} aria-label={label}></audio>
  {/if}
</div>

<style>
  .medvw-root {
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg-inset);
    padding: var(--space-4);
  }

  .medvw-video {
    width: 100%;
    max-width: 1000px;
    max-height: 100%;
    border-radius: var(--radius-sm);
    background: #000;
  }

  .medvw-audio {
    width: 100%;
    max-width: 600px;
  }
</style>
