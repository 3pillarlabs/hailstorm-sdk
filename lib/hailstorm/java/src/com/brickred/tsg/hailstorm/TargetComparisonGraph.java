package com.brickred.tsg.hailstorm;

import java.awt.Color;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

import org.jfree.chart.ChartUtilities;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.axis.CategoryAxis;
import org.jfree.chart.axis.NumberAxis;
import org.jfree.chart.plot.CategoryPlot;
import org.jfree.chart.renderer.category.LineAndShapeRenderer;
import org.jfree.data.category.DefaultCategoryDataset;

public class TargetComparisonGraph {

	private enum Mode {
		cpu, memory
	};

	private Mode mode;
	private String graphFilePath;
	private DefaultCategoryDataset dataSet;

	public static TargetComparisonGraph getCpuComparisionBuilder(
			String graphPath) {

		TargetComparisonGraph builder = new TargetComparisonGraph();
		builder.setMode(Mode.cpu);
		builder.setGraphPath(graphPath);

		return builder;
	}

	public static TargetComparisonGraph getMemoryComparisionBuilder(
			String graphPath) {

		TargetComparisonGraph builder = new TargetComparisonGraph();
		builder.setMode(Mode.memory);
		builder.setGraphPath(graphPath);

		return builder;
	}

	public void addDataItem(double value, String rowKey, String columnKey) {

		getDataSet().addValue(value, rowKey, columnKey);
	}

	public ChartModel build(int width, int height) throws IOException {

		String valueKey = null;
		switch (mode) {
		case cpu:
			valueKey = "CPU Usage (%)";
			break;
		case memory:
			valueKey = "Memory Usage (MB)";
			break;

		}

		NumberAxis rangeAxis = new NumberAxis(valueKey);
		rangeAxis.setAutoRangeIncludesZero(false);

		CategoryPlot plot = new CategoryPlot(getDataSet(), new CategoryAxis(
				"Virtual Users"), rangeAxis, new LineAndShapeRenderer(true,
				true));

		JFreeChart chart = new JFreeChart(plot);
		chart.setBackgroundPaint(Color.white);

		String outFilePath = String.format("%s.png", graphFilePath);
		OutputStream outStream = new FileOutputStream(outFilePath);
		ChartUtilities.writeChartAsPNG(outStream, chart, width, height);
		outStream.close();

		return new ChartModel(outFilePath, width, height);
	}

	private void setMode(Mode mode) {
		this.mode = mode;
	}

	private void setGraphPath(String graphPath) {
		this.graphFilePath = graphPath;
	}

	private DefaultCategoryDataset getDataSet() {

		if (dataSet == null) {
			dataSet = new DefaultCategoryDataset();
		}

		return dataSet;
	}

}
