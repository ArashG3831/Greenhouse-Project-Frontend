<!-- src/lib/components/LightControlCard.svelte -->
<script lang="ts">
    /* ─────────────────── imports ─────────────────── */
    import {
        onMount,
        onDestroy,
        tick,
        createEventDispatcher,
    } from 'svelte';
    import { browser } from '$app/environment';

    /* ─────────────────── public props ────────────── */
    /** 0 – 100 */
    export let intensity = 50;
    /** any CSS colour (hex or rgb string) */
    export let color = '#ff0000';

    const dispatch = createEventDispatcher();
    function send() {
        dispatch('update', { intensity, color });
    }

    /* ─────────────── slider handler ──────────────── */
    function onSlide(e: InputEvent) {
        intensity = +(e.target as HTMLInputElement).value;
        send();
    }

    /* ────────────────── colour-picker state ─────── */
    let isOpen = false;
    let isRgbInput = false;
    let inputValue = color;

    let containerRef: HTMLDivElement;
    let pickerRef: HTMLDivElement;
    let iroLib;
    let picker;

    /* ────────────────── helpers ──────────────────── */
    function syncPickerToState() {
        if (!picker) return;
        if (isRgbInput) {
            const { r, g, b } = picker.color.rgb;
            inputValue = `${r},${g},${b}`;
        } else {
            inputValue = picker.color.hexString;
        }
    }

    function openPicker(e: MouseEvent) {
        e.stopPropagation();
        if (isOpen) return;
        isOpen = true;
        // Wait for DOM, then lazily create iro instance if first time
        tick().then(() => {
            if (!picker && iroLib && pickerRef) {
                picker = new iroLib.ColorPicker(pickerRef, {
                    width: 200,
                    color,
                    layout: [
                        { component: iroLib.ui.Wheel },
                        { component: iroLib.ui.Slider, options: { sliderType: 'value' } },
                    ],
                });

                picker.on('color:change', (c) => {
                    color = c.hexString;
                    syncPickerToState();
                    send();
                });
            }
        });
    }

    function handleClickOutside(e: MouseEvent) {
        if (containerRef && !containerRef.contains(e.target as Node)) {
            isOpen && (isOpen = false);
        }
    }

    function onInputChange() {
        const v = inputValue.trim();

        /* HEX mode */
        if (!isRgbInput) {
            if (/^#?[0-9A-Fa-f]{6}$/.test(v)) {
                color = v.startsWith('#') ? v : `#${v}`;
                if (picker) picker.color.hexString = color;
                send();
            }
        }
        /* RGB mode */
        else {
            const parts = v.split(',').map((x) => +x.trim());
            if (
                parts.length === 3 &&
                parts.every((n) => Number.isInteger(n) && n >= 0 && n <= 255)
            ) {
                color = `rgb(${parts.join(',')})`;
                if (picker)
                    picker.color.rgb = { r: parts[0], g: parts[1], b: parts[2] };
                send();
            }
        }
    }

    /* ───────────── lifecycle – lazy-load iro.js ─── */
    onMount(async () => {
        if (!browser) return;
        const mod = await import('@jaames/iro');
        iroLib = mod.default;
        document.addEventListener('click', handleClickOutside);
    });

    onDestroy(() => {
        if (!browser) return;
        document.removeEventListener('click', handleClickOutside);
        picker && picker.destroy();
    });
</script>

<!-- ────────────────────────── markup ────────────────────────── -->
<div class="light-card" bind:this={containerRef}>
    <h3>Light Control</h3>

    <div class="body">
        <!-- Intensity slider -->
        <div class="intensity">
            <label>Intensity: {intensity}%</label>
            <input
                    type="range"
                    min="0"
                    max="100"
                    bind:value={intensity}
                    on:input={onSlide}
            />
        </div>

        <!-- Colour swatch / picker -->
        <button class="swatch" style="background:{color}" on:click={openPicker} />

        {#if isOpen}
            <div class="popup" bind:this={pickerRef}>
                <div class="iro-mount"></div>

                <!-- manual input + RGB/HEX toggle -->
                <div class="input-row">
                    <input
                            type="text"
                            bind:value={inputValue}
                            on:input={onInputChange}
                            placeholder={isRgbInput ? 'r,g,b' : '#RRGGBB'}
                    />

                    <div class="toggle">
                        <label>
                            <input
                                    type="checkbox"
                                    bind:checked={isRgbInput}
                                    on:change={() => {
									// convert shown text when switching mode
									isRgbInput = !isRgbInput;
									syncPickerToState();
								}}
                            />
                            <span>{isRgbInput ? 'RGB' : 'HEX'}</span>
                        </label>
                    </div>
                </div>
            </div>
        {/if}
    </div>
</div>

<style>
    .light-card {
        background: var(--card-bg);
        color: var(--card-text);
        border-radius: 8px;
        padding: 1rem;
        box-shadow: 0 4px 10px rgb(0 0 0 / 10%);
    }

    .body {
        display: flex;
        gap: 1.5rem;
        align-items: center;
        flex-wrap: wrap;
    }

    .intensity {
        flex: 1 1 220px;
        min-width: 200px;
    }
    .intensity label {
        display: block;
        margin-bottom: 4px;
        font-size: 0.9rem;
    }
    .intensity input {
        width: 100%;
    }

    /* colour picker bits */
    .swatch {
        width: 36px;
        height: 36px;
        border-radius: 6px;
        border: 2px solid #ccc;
        cursor: pointer;
        box-shadow: 0 0 4px rgb(0 0 0 / 0.2);
    }

    .popup {
        position: absolute;
        top: 44px;
        left: 0;
        z-index: 999;
        background: #fff;
        padding: 10px;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgb(0 0 0 / 0.3);
    }

    .iro-mount {
        margin-bottom: 8px;
    }

    .input-row {
        display: flex;
        gap: 8px;
        align-items: center;
    }
    .input-row input {
        flex: 1 1 auto;
        min-width: 100px;
        padding: 4px 6px;
        border: 1px solid #ccc;
        border-radius: 4px;
        font-family: monospace;
        font-size: 0.9rem;
    }

    .toggle label {
        display: flex;
        align-items: center;
        gap: 4px;
        font-size: 0.75rem;
        user-select: none;
    }

    /* stack neatly on phones */
    @media (max-width: 768px) {
        .body {
            flex-direction: column;
            align-items: stretch;
        }
    }
</style>
