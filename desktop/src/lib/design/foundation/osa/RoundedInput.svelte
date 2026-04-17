<!--
	RoundedInput.svelte
	iOS-style rounded input using Foundation tokens (no Tailwind).

	Usage:
	<RoundedInput
		label="Email"
		type="email"
		placeholder="you@company.com"
		bind:value={email}
	/>
-->
<script lang="ts">
	import type { HTMLInputAttributes } from 'svelte/elements';

	interface Props {
		label?: string;
		type?: string;
		value?: string;
		placeholder?: string;
		disabled?: boolean;
		required?: boolean;
		autocomplete?: HTMLInputAttributes['autocomplete'];
		error?: string;
		helperText?: string;
		id?: string;
		name?: string;
		class?: string;
	}

	let {
		label,
		type = 'text',
		value = $bindable(''),
		placeholder,
		disabled = false,
		required = false,
		autocomplete,
		error,
		helperText,
		id,
		name,
		class: className = ''
	}: Props = $props();

	const inputId = id || `input-${Math.random().toString(36).substr(2, 9)}`;
</script>

<div class="osa-input-group">
	{#if label}
		<label for={inputId} class="osa-input-label">
			{label}
			{#if required}
				<span class="osa-input-required">*</span>
			{/if}
		</label>
	{/if}

	<input
		id={inputId}
		{name}
		{type}
		bind:value
		{placeholder}
		{disabled}
		{required}
		{autocomplete}
		class="input-rounded {className}"
		class:osa-input--error={error}
		aria-invalid={error ? 'true' : 'false'}
		aria-describedby={error ? `${inputId}-error` : helperText ? `${inputId}-helper` : undefined}
	/>

	{#if error}
		<p id="{inputId}-error" class="osa-input-error">{error}</p>
	{:else if helperText}
		<p id="{inputId}-helper" class="osa-input-helper">{helperText}</p>
	{/if}
</div>

<style>
	.osa-input-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.osa-input-label {
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--dt2);
	}
	.osa-input-required {
		color: #ef4444;
	}
	.osa-input--error {
		border-color: #ef4444 !important;
	}
	.osa-input-error {
		font-size: 0.8125rem;
		color: #ef4444;
		margin: 0;
		animation: osa-slide-down 0.15s ease-out;
	}
	.osa-input-helper {
		font-size: 0.8125rem;
		color: var(--dt3);
		margin: 0;
	}
	@keyframes osa-slide-down {
		from { opacity: 0; transform: translateY(-4px); }
		to { opacity: 1; transform: translateY(0); }
	}
</style>
