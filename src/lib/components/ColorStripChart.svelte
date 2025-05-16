<script>
    export let colors = [];
    export let timestamps = [];

    let containerEl;
    let visibleColors = [];
    let visibleTimestamps = [];

    function updateVisibleData() {
        if (!containerEl) return;

        const width = containerEl.clientWidth;
        const step = Math.max(1, Math.floor(colors.length / width));
        visibleColors = colors.filter((_, i) => i % step === 0);
        visibleTimestamps = timestamps.filter((_, i) => i % step === 0);
    }

    function getTickCount() {
        const width = containerEl?.clientWidth || 1000;
        if (width < 400) return 3;
        if (width < 600) return 4;
        if (width < 768) return 5;
        return 6;
    }

    import { onMount } from 'svelte';
    onMount(() => {
        updateVisibleData();
        window.addEventListener('resize', updateVisibleData);
        return () => window.removeEventListener('resize', updateVisibleData);
    });

    function formatTime(ts) {
        const date = new Date(ts);
        return date.toLocaleString('en-US', {
            hour: 'numeric',
            weekday: 'short',
            hour12: true
        });
    }
</script>

<!-- Wrapper fills 100% of .chart-container (300px) -->
<div class="chart-wrapper" bind:this={containerEl}>
    <div class="color-strip">
        {#each visibleColors as color}
            <div class="color-block" style="background-color: {color};"></div>
        {/each}
    </div>

    <div class="tick-strip">
        {#each visibleTimestamps as ts, i}
            {#if i % Math.floor(visibleTimestamps.length / getTickCount()) === 0}
                <span class="tick-label">{formatTime(ts)}</span>
            {/if}
        {/each}
    </div>
</div>

<style>
    .chart-wrapper {
        display: flex;
        flex-direction: column;
        height: 100%;
        width: 100%;
        overflow: hidden; /* <-- 🔪 overflow killed here too */
    }


    .color-strip {
        display: flex;
        flex: 1 1 auto;
        border-radius: 8px 8px 0 0;
        overflow: hidden;
    }

    .color-block {
        flex: 1 0 auto;
        height: 100%;
    }

    .tick-strip {
        height: 60px; /* was 40px */
        display: flex;
        justify-content: space-between;
        align-items: flex-end;
        font-size: 12px;
        padding: 0 6px 4px 12px;
        color: var(--text-color);
        border-top: none;
        background: transparent;
        box-sizing: border-box;
        overflow: hidden;

    }


    .tick-label {
        white-space: nowrap;
        max-width: 70px;
        overflow: hidden;
        text-overflow: ellipsis;
        text-align: left;
        transform-origin: bottom left;
        margin-bottom: 2px; /* <- helps shift it down slightly */
    }

    @media (max-width: 768px) {
        .tick-label {
            transform: rotate(-45deg);
            font-size: 10px;
        }
    }


    @media (max-width: 768px) {
        .tick-label {
            transform: rotate(-45deg);
            font-size: 10px;

        }
    }

    @media (max-width: 768px) {
        .tick-strip {
            padding-top: 8px; /* only on mobile */

        }
    }

    @media (min-width: 768px) {
        .tick-strip {
            height: 30px; /* Override on tablets and larger */
        }
    }
</style>
