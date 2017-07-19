package com.brickred.tsg.hailstorm;

import java.awt.Color;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

import org.jfree.chart.ChartUtilities;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.axis.NumberAxis;
import org.jfree.chart.plot.CombinedDomainXYPlot;
import org.jfree.chart.plot.XYPlot;
import org.jfree.chart.renderer.xy.StandardXYItemRenderer;
import org.jfree.data.xy.XYSeries;
import org.jfree.data.xy.XYSeriesCollection;

public class ResourceUtilizationGraph {

	private final String graphFilePath;
	private final int samplingInterval;
	private Ticker cpuTicker;
	private Ticker memoryTicker;
	private Ticker swapTicker;
	private XYSeries cpuSeries;
	private XYSeries memorySeries;
	private XYSeries swapSeries;
	private JFreeChart utilizationChart;

	public ResourceUtilizationGraph(String graphFilePath, int samplingInterval) {
		this.graphFilePath = graphFilePath;
		this.samplingInterval = samplingInterval;
	}

	/**
	 * Lazily loads all data in a graph as there may be a lot of data for
	 * resource utilization. This is different from the standard in-memory
	 * approach for other graphs.
	 * 
	 * @return
	 * @throws IOException
	 */
	public void startBuilder() {

		CombinedDomainXYPlot plot = new CombinedDomainXYPlot(new NumberAxis(
				"Elapsed Time, seconds"));

		plot.add(createCpuPlot(), 1);
		plot.add(createMemoryPlot(), 1);
		plot.add(createSwapPlot(), 1);

		utilizationChart = new JFreeChart("", plot);
		utilizationChart.setBackgroundPaint(Color.white);
	}

	private XYPlot createCpuPlot() {

		cpuTicker = new Ticker(samplingInterval);

		String key = "Total CPU Used (%)";
		XYSeriesCollection dataSet = new XYSeriesCollection();
		cpuSeries = new XYSeries(key);
		dataSet.addSeries(cpuSeries);
		XYPlot plot = new XYPlot(dataSet, null, new NumberAxis(key),
				new StandardXYItemRenderer());

		return plot;
	}

	private XYPlot createMemoryPlot() {

		memoryTicker = new Ticker(samplingInterval);

		String key = "Memory Used (MB)";
		XYSeriesCollection dataSet = new XYSeriesCollection();
		memorySeries = new XYSeries(key);
		dataSet.addSeries(memorySeries);
		NumberAxis rangeAxis = new NumberAxis(key);
		rangeAxis.setAutoRangeIncludesZero(false);
		XYPlot plot = new XYPlot(dataSet, null, rangeAxis,
				new StandardXYItemRenderer());
		return plot;
	}

	private XYPlot createSwapPlot() {

		swapTicker = new Ticker(samplingInterval);

		String key = "Swap Used (MB)";
		XYSeriesCollection dataSet = new XYSeriesCollection();
		swapSeries = new XYSeries(key);
		dataSet.addSeries(swapSeries);
		XYPlot plot = new XYPlot(dataSet, null, new NumberAxis(key),
				new StandardXYItemRenderer());

		return plot;
	}

	public void addCpuUsageSample(double sample) {
		cpuSeries.add(cpuTicker.next(), sample);
	}

	public void addMemoryUsageSample(double sample) {
		memorySeries.add(memoryTicker.next(), sample);
	}

	public void addSwapUsageSample(double sample) {
		swapSeries.add(swapTicker.next(), sample);
	}

	public ChartModel finish(int width, int height) throws IOException {

		String outFilePath = String.format("%s.png", graphFilePath);
		OutputStream chartOutputStream = new FileOutputStream(outFilePath);
		ChartUtilities.writeChartAsPNG(chartOutputStream, utilizationChart,
				width, height);
		chartOutputStream.close();

		return new ChartModel(outFilePath, width, height);
	}

	private static class Ticker {

		private int counter;
		private final int increment;

		public Ticker(int increment) {
			this.increment = increment;
			this.counter = 0;
		}

		public double next() {
			return (++counter) * increment;
		}
	}

}
