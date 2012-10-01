package com.brickred.tsg.hailstorm;

import java.awt.BasicStroke;
import java.awt.Color;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

import org.jfree.chart.ChartUtilities;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.axis.AxisLocation;
import org.jfree.chart.axis.CategoryAxis;
import org.jfree.chart.axis.NumberAxis;
import org.jfree.chart.plot.CategoryPlot;
import org.jfree.chart.plot.CombinedDomainCategoryPlot;
import org.jfree.chart.plot.DatasetRenderingOrder;
import org.jfree.chart.plot.PlotOrientation;
import org.jfree.chart.renderer.category.BarRenderer;
import org.jfree.chart.renderer.category.LevelRenderer;
import org.jfree.chart.renderer.category.LineAndShapeRenderer;
import org.jfree.chart.renderer.category.StackedBarRenderer;
import org.jfree.chart.renderer.category.StandardBarPainter;
import org.jfree.data.category.CategoryDataset;
import org.jfree.data.category.DefaultCategoryDataset;
import org.jfree.data.general.DatasetUtilities;

public class AggregateGraph {

	private final String graphFilePath;
	private String[] pages;
	private String[] thresholdTitles;
	private double[][] thresholdData;
	private double[] errorPercentages;
	private double[] minResponseTimes;
	private double[] avgResponseTimes;
	private double[] medianResponseTimes;
	private double[] ninetyCentileResponseTimes;
	private double[] maxResponseTimes;

	public AggregateGraph(String graphFilePath) {
		this.graphFilePath = graphFilePath;
	}

	public AggregateGraph setPages(String[] pages) {
		this.pages = pages;
		return this;
	}

	public AggregateGraph setMinResponseTimes(double[] minResponseTimes) {
		this.minResponseTimes = minResponseTimes;
		return this;
	}

	public AggregateGraph setAvgResponseTimes(double[] avgResponseTimes) {
		this.avgResponseTimes = avgResponseTimes;
		return this;
	}

	public AggregateGraph setMedianResponseTimes(double[] medianResponseTimes) {
		this.medianResponseTimes = medianResponseTimes;
		return this;
	}

	public AggregateGraph setNinetyCentileResponseTimes(
			double[] ninetyCentileResponseTimes) {
		this.ninetyCentileResponseTimes = ninetyCentileResponseTimes;
		return this;
	}

	public AggregateGraph setMaxResponseTimes(double[] maxResponseTimes) {
		this.maxResponseTimes = maxResponseTimes;
		return this;
	}

	public AggregateGraph setThresholdTitles(String[] thresholdTitles) {
		this.thresholdTitles = thresholdTitles;
		return this;
	}

	public AggregateGraph setThresholdData(double[][] thresholdData) {
		this.thresholdData = thresholdData;
		return this;
	}

	public AggregateGraph setErrorPercentages(double[] errorPercentages) {
		this.errorPercentages = errorPercentages;
		return this;
	}

	public String create() throws IOException {

		CategoryPlot prtPlot = createPageResponseTimePlot();
		CategoryPlot pfPlot = createPageFiguresPlot();

		CategoryAxis domainAxis = new CategoryAxis("Pages");
		domainAxis.setUpperMargin(0.01);
		domainAxis.setLowerMargin(0.01);
		domainAxis.setCategoryMargin(0.4f);
		CombinedDomainCategoryPlot plot = new CombinedDomainCategoryPlot(
				domainAxis);

		plot.add(prtPlot, 3);
		plot.add(pfPlot, 1);

		plot.setOrientation(PlotOrientation.HORIZONTAL);

		JFreeChart chart = new JFreeChart("", plot);
		chart.setBackgroundPaint(Color.white);

		String outFile = String.format("%s.png", graphFilePath);
		OutputStream outputStream = new FileOutputStream(outFile);
		int chartWidth = 640;
		int chartHeight = pages.length * 80;
		chartHeight = chartHeight > 800 ? 800 : chartHeight;

		ChartUtilities.writeChartAsPNG(outputStream, chart, chartWidth,
				chartHeight);
		outputStream.close();

		return outFile;
	}

	private CategoryPlot createPageResponseTimePlot() {

		CategoryPlot plot = new CategoryPlot();
		plot.setRangeAxis(new NumberAxis("Response Times (ms)"));

		// ninety percentile bar
		CategoryDataset ninetyPercentile = DatasetUtilities
				.createCategoryDataset(new String[] { "90 percentile" }, pages,
						new double[][] { ninetyCentileResponseTimes });
		BarRenderer barRenderer = new BarRenderer();
		barRenderer.setSeriesPaint(0, ninetyPercentileColor);
		barRenderer.setShadowVisible(false);
		barRenderer.setBarPainter(new StandardBarPainter());
		plot.setDataset(0, ninetyPercentile);
		plot.setRenderer(0, barRenderer);

		List<String> levelTitles = new ArrayList<String>();
		List<Color> levelColors = new ArrayList<Color>();
		List<double[]> responseTimeData = new ArrayList<double[]>();

		if (minResponseTimes != null) {
			levelTitles.add("Minimum");
			levelColors.add(minimumColor);
			responseTimeData.add(minResponseTimes);
		}

		if (avgResponseTimes != null) {
			levelTitles.add("Average");
			levelColors.add(averageColor);
			responseTimeData.add(avgResponseTimes);
		}

		if (maxResponseTimes != null) {
			levelTitles.add("Maximum");
			levelColors.add(maximumColor);
			responseTimeData.add(maxResponseTimes);
		}

		if (medianResponseTimes != null) {
			levelTitles.add("Median");
			levelColors.add(medianColor);
			responseTimeData.add(medianResponseTimes);
		}

		for (int i = 0; i < levelTitles.size(); i++) {
			CategoryDataset dataset = DatasetUtilities.createCategoryDataset(
					new String[] { levelTitles.get(i) }, pages,
					new double[][] { responseTimeData.get(i) });

			LevelRenderer renderer = new LevelRenderer();
			renderer.setSeriesPaint(0, levelColors.get(i));
			renderer.setSeriesStroke(0, new BasicStroke(2.0f));

			plot.setDataset(i + 1, dataset);
			plot.setRenderer(i + 1, renderer);
		}

		plot.setDatasetRenderingOrder(DatasetRenderingOrder.FORWARD);

		return plot;
	}

	private CategoryPlot createPageFiguresPlot() {

		CategoryPlot plot = new CategoryPlot();
		NumberAxis rangeAxis = new NumberAxis("% requests");
		plot.setRangeAxis(rangeAxis);
		plot.setRangeAxisLocation(AxisLocation.BOTTOM_OR_RIGHT);
		plot.setDatasetRenderingOrder(DatasetRenderingOrder.FORWARD);

		List<Color> thresholdColors = new ArrayList<Color>(
				thresholdTitles.length);
		thresholdColors.add(Color.green);
		thresholdColors.add(Color.yellow);
		thresholdColors.add(Color.orange);
		thresholdColors.add(Color.red);

		if (thresholdTitles.length > 4) {
			int green = 221; // DD
			for (int i = 2; i < thresholdTitles.length - 2; i++) {
				thresholdColors.add(i, new Color(255, green, 0));
				green -= 10; // reducing green brings closer to orange
			}
		}

		CategoryDataset thresholdDataset = DatasetUtilities
				.createCategoryDataset(thresholdTitles, pages, thresholdData);

		StackedBarRenderer thresholdRenderer = new StackedBarRenderer();
		for (int i = 0; i < thresholdColors.size(); i++) {
			thresholdRenderer.setSeriesPaint(i, thresholdColors.get(i));
		}
		thresholdRenderer.setShadowVisible(false);
		thresholdRenderer.setBarPainter(new StandardBarPainter());
		plot.setDataset(thresholdDataset);
		plot.setRenderer(thresholdRenderer);

		DefaultCategoryDataset errorDataset = new DefaultCategoryDataset();
		for (int i = 0; i < errorPercentages.length; i++) {
			errorDataset.addValue(errorPercentages[i], "% Errors", pages[i]);
		}
		LineAndShapeRenderer errorRenderer = new LineAndShapeRenderer(true,
				false);
		errorRenderer.setSeriesStroke(0, new BasicStroke(4f));
		errorRenderer.setSeriesPaint(0, Color.black);
		plot.setDataset(1, errorDataset);
		plot.setRenderer(1, errorRenderer);

		return plot;
	}

	// response time metric colors
	private static final Color minimumColor = Color.orange;
	private static final Color maximumColor = new Color(171, 171, 171);
	private static final Color averageColor = Color.yellow;
	private static final Color medianColor = Color.MAGENTA;
	private static final Color ninetyPercentileColor = new Color(0, 0, 255);

}
