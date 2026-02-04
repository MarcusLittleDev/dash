import Chart from 'chart.js/auto';

export const BarChart = {
  mounted() {
    this.config = JSON.parse(this.el.dataset.config);
    this.widgetId = this.el.dataset.widgetId;
    this.chart = null;

    // Parse initial data if provided
    const initialData = this.el.dataset.initialData;
    this.data = initialData ? JSON.parse(initialData) : [];

    this.initChart();

    // Listen for data updates from LiveView
    this.handleEvent(`bar_chart_data_${this.widgetId}`, (payload) => {
      this.updateData(payload.data);
    });
  },

  initChart() {
    const canvas = this.el.querySelector('canvas');
    if (!canvas) {
      console.error('BarChart: Canvas element not found');
      return;
    }

    const ctx = canvas.getContext('2d');
    const xField = this.config.x_field || 'category';
    const yField = this.config.y_field || 'value';

    const { labels, values } = this.prepareData(xField, yField);

    this.chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: yField,
          data: values,
          backgroundColor: '#3B82F6',
          borderColor: '#2563EB',
          borderWidth: 1,
          borderRadius: 4,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            grid: {
              display: false,
            },
            ticks: {
              maxTicksLimit: 10,
            }
          },
          y: {
            beginAtZero: true,
            grid: {
              color: 'rgba(0, 0, 0, 0.05)',
            }
          }
        },
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            titleFont: { size: 12 },
            bodyFont: { size: 11 },
            padding: 10,
          }
        },
        animation: {
          duration: 300
        }
      }
    });
  },

  prepareData(xField, yField) {
    const labels = this.data.map(row => row[xField] || 'Unknown');
    const values = this.data.map(row => row[yField] || 0);
    return { labels, values };
  },

  updateData(newData) {
    if (!this.chart || !newData) return;

    this.data = newData;
    const xField = this.config.x_field || 'category';
    const yField = this.config.y_field || 'value';

    const { labels, values } = this.prepareData(xField, yField);

    this.chart.data.labels = labels;
    this.chart.data.datasets[0].data = values;
    this.chart.update('none');
  },

  updated() {
    // Re-read initial data if element is updated
    const initialData = this.el.dataset.initialData;
    if (initialData) {
      const newData = JSON.parse(initialData);
      if (newData.length !== this.data.length) {
        this.updateData(newData);
      }
    }
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
  }
};
