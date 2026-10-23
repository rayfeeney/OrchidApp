(() => {
    'use strict';
    document.querySelectorAll('.greenhouse-chart').forEach(container => {
        const status = container.querySelector('.chart-status');
        try {
            const data = JSON.parse(container.querySelector('.greenhouse-data').textContent);
            const sets = [
                { type: 'bar', label: 'Cost (£)', data: data.costs, yAxisID: 'cost',
                    backgroundColor: 'rgba(42, 117, 160, 0.5)', borderWidth: 0, barThickness: 'flex',
                    barPercentage: 1, categoryPercentage: 1, order: 3 },
                { type: 'line', label: 'Actual temperature (°C)', data: data.temperatures,
                    yAxisID: 'temperature', borderColor: '#c15418', pointRadius: 0,
                    borderWidth: 1.5, spanGaps: false, tension: 0, order: 2 }
            ];
            // Each period is an independent two-point dataset: never bridge gaps.
            data.periods.forEach(period => {
                [['average', 'Average (°C)', '#7040a0', []],
                 ['target', 'Target (°C)', '#247244', [5, 4]]].forEach(([key, label, color, dash]) => {
                    if (period[key] === null) return;
                    sets.push({ type: 'line', label, data: [
                        { x: period.start, y: period[key] }, { x: period.end, y: period[key] }
                    ], yAxisID: 'temperature', borderColor: color, borderDash: dash,
                    borderWidth: 2, pointRadius: 0, pointHitRadius: 5,
                    spanGaps: false, order: 1, period });
                });
            });
            new Chart(container.querySelector('canvas'), {
                data: { datasets: sets },
                options: {
                    responsive: true, maintainAspectRatio: false, animation: false, parsing: false,
                    interaction: { mode: 'nearest', intersect: false },
                    scales: {
                        x: { type: 'linear', min: 0, max: data.labels.length,
                            ticks: { stepSize: 24, maxRotation: 0, autoSkip: true,
                                callback: value => data.labels[value]?.slice(0, 6) ?? '' },
                            title: { display: true, text: 'Europe/London' } },
                        cost: { type: 'linear', position: 'left', beginAtZero: true,
                            title: { display: true, text: 'Cost (£ / hour)' } },
                        temperature: { type: 'linear', position: 'right',
                            grace: '5%',
                            grid: { drawOnChartArea: false }, title: { display: true, text: 'Temperature (°C)' } }
                    },
                    plugins: {
                        legend: { labels: { boxWidth: 15, filter: (item, chart) =>
                            chart.datasets.findIndex(s => s.label === item.text) === item.datasetIndex } ,
                            onClick: (_event, item, legend) => {
                                const chart = legend.chart;
                                const visible = !chart.isDatasetVisible(item.datasetIndex);
                                chart.data.datasets.forEach((s, i) => {
                                    if (s.label === item.text) chart.setDatasetVisibility(i, visible);
                                });
                                chart.update();
                            } },
                        tooltip: { callbacks: {
                            title: items => {
                                const item = items[0];
                                return item?.dataset.period?.label ?? data.labels[Math.floor(item?.parsed.x ?? 0)] ?? '';
                            },
                            label: item => `${item.dataset.label}: ${item.parsed.y.toFixed(item.dataset.yAxisID === 'cost' ? 4 : 1)}`,
                            afterLabel: item => item.dataset.period ?
                                `${item.dataset.period.readingCount} readings · ${item.dataset.period.status}` : '',
                            afterBody: items => {
                                const x = items[0]?.parsed.x;
                                const p = data.periods.find(p => p.start <= x && x < p.end);
                                return p ? [p.label,
                                    `Average: ${p.average === null ? 'unavailable' : p.average.toFixed(1) + '°C'} / Target: ${p.target === null ? 'unavailable' : p.target.toFixed(1) + '°C'}`,
                                    `${p.readingCount} readings · ${p.status}`] : [];
                            }
                        } }
                    }
                }
            });
        } catch (error) {
            status.hidden = false;
            status.textContent = 'Chart could not be displayed.';
            console.error('Greenhouse chart unavailable', error);
        }
    });
})();
