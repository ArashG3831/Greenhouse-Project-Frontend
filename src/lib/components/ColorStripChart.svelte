<script>
    import Chart from "chart.js/auto";
    import { onMount } from "svelte";

    export let colors = [];
    export let timestamps = [];

    let canvasEl;
    let colorChart;

    onMount(() => {
        if (colorChart) colorChart.destroy();  // in case of remount

        const ctx = canvasEl.getContext("2d");

        colorChart = new Chart(ctx, {
            type: "bar",
            data: {
                labels: timestamps,
                datasets: [{
                    data: timestamps.map(() => 1),  // uniform height for all
                    backgroundColor: colors,
                    barPercentage: 1.0,
                    categoryPercentage: 1.0
                }]
            },
            options: {
                indexAxis: 'x',
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: {
                        ticks: {
                            callback: function(value, index) {
                                const ts = timestamps[index];
                                return new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                            },
                            color: '#666',
                            autoSkip: true,
                            maxTicksLimit: 10
                        },
                        grid: { display: false }
                    },
                    y: {
                        display: false
                    }
                },
                plugins: {
                    legend: { display: false },
                    tooltip: { enabled: false }
                }
            }
        });
    });
</script>

<canvas bind:this={canvasEl} style="width: 100%; height: 60px;"></canvas>
