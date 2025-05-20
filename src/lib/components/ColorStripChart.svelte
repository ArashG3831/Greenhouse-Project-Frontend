<script>
    import { onMount, onDestroy } from 'svelte';
    import Chart from 'chart.js/auto';

    export let colors = [];
    export let timestamps = [];

    let canvasEl;
    let chart;

    // Create the chart once the component is in the DOM
    onMount(buildChart);
    onDestroy(() => chart && chart.destroy());

    // Re-run every time colors or timestamps change
    $: if (colors.length && timestamps.length) {
        if (chart) {
            // Update in place
            chart.data.labels = [...timestamps];
            chart.data.datasets[0].backgroundColor = [...colors];
            chart.data.datasets[0].data = timestamps.map(() => 1);
            chart.update();
        } else {
            // First valid data set – build it
            buildChart();
        }
    }

    function buildChart() {
        if (chart) chart.destroy();          // safety
        if (!colors.length) return;          // nothing to show yet

        chart = new Chart(canvasEl.getContext('2d'), {
            type: 'bar',
            data: {
                labels: timestamps,
                datasets: [{
                    data: timestamps.map(() => 1),
                    backgroundColor: colors,
                    barPercentage: 1,
                    categoryPercentage: 1
                }]
            },
            options: {
                indexAxis: 'x',
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: {
                            color: '#666',
                            autoSkip: true,
                            maxTicksLimit: 10,
                            callback: (_val, idx) =>
                                new Date(timestamps[idx])
                                    .toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                        }
                    },
                    y: { display: false }
                },
                plugins: { legend: { display: false }, tooltip: { enabled: false } }
            }
        });
    }
</script>

<canvas bind:this={canvasEl} style="width:100%;height:60px"></canvas>
