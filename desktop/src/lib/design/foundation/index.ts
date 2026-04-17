// UI Primitives - Svelte/Bits UI Components
// Based on AFFiNE patterns, adapted for BusinessOS

// Core Components
export { default as Button } from "./button/Button.svelte";
export { default as Input } from "./input/Input.svelte";
export { default as Loading } from "./loading/Loading.svelte";
export { default as Skeleton } from "./skeleton/Skeleton.svelte";
export { default as Separator } from "./separator/Separator.svelte";

// Overlay Components
export { default as Modal } from "./modal/Modal.svelte";
export { default as Tooltip } from "./tooltip/Tooltip.svelte";
export { default as Popover } from "./popover/Popover.svelte";

// Menu Components
export { Menu, MenuItem, MenuSeparator, MenuLabel, MenuGroup } from "./menu";

// Tab Components
export { Tabs, TabsList, TabsTrigger, TabsContent } from "./tabs";

// Form Control Components
export { default as Textarea } from "./textarea/Textarea.svelte";
export { default as Slider } from "./slider/Slider.svelte";
export { default as Toggle } from "./toggle/Toggle.svelte";
export { default as Checkbox } from "./checkbox/Checkbox.svelte";
export { RadioGroup, RadioItem } from "./radio";
export { default as Select } from "./select/Select.svelte";

// Media Components
export { default as Avatar } from "./avatar/Avatar.svelte";
export { default as AvatarGroup } from "./avatar/AvatarGroup.svelte";

// Layout Components
export { default as ScrollArea } from "./scroll-area/ScrollArea.svelte";

// Feedback Components
export { default as Alert } from "./alert/Alert.svelte";
export { default as Progress } from "./progress/Progress.svelte";
export { default as Toast } from "./toast/Toast.svelte";
export { default as Toaster } from "./toast/Toaster.svelte";
export { toast } from "./toast/toast.js";
export type { Toast as ToastItem, ToastType } from "./toast/toast.js";

// Table Components
export { Table, TableHeader, TableRow, TableCell } from "./table";

// Breadcrumb Components
export { Breadcrumb, BreadcrumbItem } from "./breadcrumb";

// Disclosure Components
export { Accordion, AccordionItem } from "./accordion";

// OSA Components (iOS-inspired, token-driven)
export {
  PillButton,
  GlassCard,
  GradientBackground,
  RoundedInput,
  AppCard,
  ProgressDots,
} from "./osa";
