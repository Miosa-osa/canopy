import { writable } from "svelte/store";

export type ToastType = "success" | "error" | "warning" | "info";

export interface Toast {
  id: string;
  type: ToastType;
  title: string;
  description?: string;
  duration?: number;
}

function createToastStore() {
  const { subscribe, update } = writable<Toast[]>([]);

  function add(toast: Omit<Toast, "id">): string {
    const id = Math.random().toString(36).slice(2, 9);
    const duration = toast.duration ?? 4000;

    update((toasts) => [...toasts, { ...toast, id, duration }]);

    if (duration > 0) {
      setTimeout(() => dismiss(id), duration);
    }

    return id;
  }

  function dismiss(id: string) {
    update((toasts) => toasts.filter((t) => t.id !== id));
  }

  function success(
    title: string,
    description?: string,
    duration?: number,
  ): string {
    return add({ type: "success", title, description, duration });
  }

  function error(
    title: string,
    description?: string,
    duration?: number,
  ): string {
    return add({ type: "error", title, description, duration });
  }

  function warning(
    title: string,
    description?: string,
    duration?: number,
  ): string {
    return add({ type: "warning", title, description, duration });
  }

  function info(
    title: string,
    description?: string,
    duration?: number,
  ): string {
    return add({ type: "info", title, description, duration });
  }

  return { subscribe, add, dismiss, success, error, warning, info };
}

export const toast = createToastStore();
