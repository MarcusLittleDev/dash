import Chart from 'chart.js/auto';
import 'chartjs-adapter-date-fns';

export const LineChart = {
  mounted() {
    this.config = JSON.parse(this.el.dataset.config);
    this.widgetId = this.el.dataset.widgetId;
    this.chart = null;

    // Parse initial data if provided
    const initialData = this.el.dataset.initialData;
    this.data = initialData ? JSON.parse(initialData) : [];

    this.initChart();

    // Listen for data updates from LiveView
    this.handleEvent(`chart_data_${this.widgetId}`, (payload) => {
      this.updateData(payload.data);
    });
  },

  initChart() {
    const canvas = this.el.querySelector('canvas');
    if (!canvas) {
      console.error('LineChart: Canvas element not found');
      return;
    }

    const ctx = canvas.getContext('2d');
    const yFields = this.config.y_fields || [];
    const xField = this.config.x_field || 'timestamp';

    const datasets = yFields.map((field, index) => ({
      label: field.label || field.field,
      data: this.prepareDataPoints(xField, field.field),
      borderColor: field.color || this.getColor(index),
      backgroundColor: 'transparent',
      tension: 0.2,
      pointRadius: 0,
      borderWidth: 2,
    }));

    this.chart = new Chart(ctx, {
      type: 'line',
      data: { datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false,
        },
        scales: {
          x: {
            type: 'time',
            time: {
              unit: 'minute',
              displayFormats: {
                minute: 'HH:mm',
                hour: 'HH:mm',
              }
            },
            grid: {
              display: false,
            },
            ticks: {
              maxTicksLimit: 6,
            }
          },
          y: {
            beginAtZero: false,
            grid: {
              color: 'rgba(0, 0, 0, 0.05)',
            }
          }
        },
        plugins: {
          legend: {
            position: 'top',
            labels: {
              boxWidth: 12,
              padding: 10,
              font: {
                size: 11
              }
            }
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

  prepareDataPoints(xField, yField) {
    return this.data
      .map(row => ({
        x: new Date(row[xField]),
        y: row[yField]
      }))
      .filter(p => p.y !== undefined && p.y !== null)
      .sort((a, b) => a.x - b.x);
  },

  updateData(newData) {
    if (!this.chart || !newData) return;

    this.data = newData;
    const xField = this.config.x_field || 'timestamp';
    const yFields = this.config.y_fields || [];

    yFields.forEach((field, index) => {
      if (this.chart.data.datasets[index]) {
        this.chart.data.datasets[index].data = this.prepareDataPoints(xField, field.field);
      }
    });

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

  getColor(index) {
    const colors = ['#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899', '#06B6D4'];
    return colors[index % colors.length];
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
  }
};
