<script lang="ts">
    import { createEventDispatcher } from 'svelte';

    export let intensity = 50;
    export let color = '#ff0000';
    export let isLoggedIn: boolean = false; // passed in from parent

    const dispatch = createEventDispatcher();

    function send() {
        dispatch('update', { intensity, color });
    }

    function onSlide(e: InputEvent) {
        if (!isLoggedIn) return;
        intensity = +(e.target as HTMLInputElement).value;
        send();
    }

    function onColorChange(e: Event) {
        if (!isLoggedIn) return;
        color = (e.target as HTMLInputElement).value;
        send();
    }
</script>

<div class="light-card sensor-card text-center control-card-container">
    <h3>Light Control</h3>

    {#if !isLoggedIn}
        <div class="control-overlay"></div> <!-- ✅ NOW in the correct place -->
    {/if}

    <div class="body my-2">
        <div class="intensity">
            <label style="font-size: 18px">Intensity: {intensity}%</label>
            <input
                    type="range"
                    min="0"
                    max="100"
                    bind:value={intensity}
                    on:input={onSlide}
                    disabled={!isLoggedIn}
            />
        </div>

        <div class="color-picker">
            <input
                    type="color"
                    bind:value={color}
                    on:input={onColorChange}
                    disabled={!isLoggedIn}
            />
        </div>
    </div>
</div>


<style>
    /* ----------- Custom Range Slider Styles ----------- */
    input[type="range"] {
        -webkit-appearance: none;
        width: 100%;
        height: 8px;
        background: var(--slider-track, lightgray);
        border-radius: 5px;
        outline: none;
        transition: background 0.3s;
        cursor: pointer;
    }

    /* Track on hover */
    input[type="range"]:hover {
        background: var(--slider-hover-track, #aaa);
    }

    /* WebKit slider thumb (Chrome, Safari) */
    input[type="range"]::-webkit-slider-thumb {
        -webkit-appearance: none;
        height: 20px;
        width: 20px;
        border-radius: 50%;
        background: var(--slider-thumb, #007a7a);
        border: 2px solid white;
        box-shadow: 0 0 2px rgba(0,0,0,0.3);
        transition: background 0.2s ease;
    }

    /* Firefox */
    input[type="range"]::-moz-range-thumb {
        height: 20px;
        width: 20px;
        border-radius: 50%;
        background: var(--slider-thumb, #007a7a);
        border: 2px solid white;
        box-shadow: 0 0 2px rgba(0,0,0,0.3);
    }

    /* IE / Edge Legacy (optional) */
    input[type="range"]::-ms-thumb {
        height: 20px;
        width: 20px;
        border-radius: 50%;
        background: var(--slider-thumb, #007a7a);
        border: 2px solid white;
    }

    /* Dark theme support */
    :global(.dark) {
        --slider-track: #444;
        --slider-hover-track: #666;
        --slider-thumb: #00cccc;
    }

    .light-card {
        position: relative; /* ✅ Required so overlay absolutely positions inside it */
        background: var(--card-bg);
        color: var(--card-text);
        border-radius: 8px;
        padding: 1rem;
        box-shadow: 0 4px 10px rgb(0 0 0 / 10%);
    }

    .body {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 1rem;
        flex-wrap: wrap;
        width: 100%;
        position: relative;
    }

    .intensity { flex: 1 1 auto; }

    .intensity label { display: block; margin-bottom: 4px; font-size: .9rem; }

    .intensity input[type='range'] { width: 100%; }

    .color-picker {
        display: flex;
        align-items: center;
        justify-content: center;
    }

    .color-picker input[type='color'] {
        width: 36px;
        height: 36px;
        padding: 0;
        border: none;
        outline: none;
        cursor: pointer;
        border-radius: 50%;
        -webkit-appearance: none;
    }

    .color-picker input[type='color']::-webkit-color-swatch-wrapper {
        padding: 0;
        border: none;
    }

    .color-picker input[type='color']::-webkit-color-swatch {
        border: none;
        border-radius: 50%;
    }

    .color-picker input[type='color']::-moz-color-swatch {
        border: none;
        border-radius: 50%;
    }

    /* 🔒 Overlay for guest users */
    .control-overlay {
        position: absolute;
        border-radius: 10px;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(128, 128, 128, 0.5); /* same as other cards */
        z-index: 10;
    }

    @media (max-width: 768px) {
        .body {
            flex-direction: row;
            flex-wrap: nowrap;
        }

        .intensity {
            flex: 1;
        }

        .color-picker {
            margin-left: .5rem;
        }
    }
</style>
