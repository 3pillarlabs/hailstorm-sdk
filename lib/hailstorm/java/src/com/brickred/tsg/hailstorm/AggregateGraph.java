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
import org.jfree.chart.axis.CategoryAxis;
import org.jfree.chart.axis.NumberAxis;
import org.jfree.chart.plot.CategoryPlot;
import org.jfree.chart.plot.CombinedDomainCategoryPlot;
import org.jfree.chart.plot.DatasetRenderingOrder;
import org.jfree.chart.plot.PlotOrientation;
import org.jfree.chart.renderer.category.BarRenderer;
import org.jfree.chart.renderer.category.LevelRenderer;
import org.jfree.chart.renderer.category.StackedBarRenderer;
import org.jfree.chart.renderer.category.StandardBarPainter;
import org.jfree.data.category.CategoryDataset;
import org.jfree.data.general.DatasetUtilities;


public class AggregateGraph {

	private String graphFilePath;
	private String[] pages;
	private double[][] responseTimeData;
	private String[] thresholdTitles;
	private double[][] thresholdData;

	public AggregateGraph(String graphFilePath) {
		this.graphFilePath = graphFilePath;
	}
	
	public AggregateGraph setPages(String[] pages) {
		this.pages = pages;
		return this;
	}
	
	public AggregateGraph setResponseTimes(double[][] responseTimes) {
		this.responseTimeData = responseTimes;
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

	public String create() throws IOException {

		CategoryPlot prtPlot = createPageResponseTimePlot();
		CategoryPlot pfPlot = createPageFiguresPlot();
		
		CategoryAxis domainAxis = new CategoryAxis("Pages");
		domainAxis.setUpperMargin(0.01);
		domainAxis.setLowerMargin(0.01);
		domainAxis.setCategoryMargin(0.4f);
		CombinedDomainCategoryPlot plot = new CombinedDomainCategoryPlot(domainAxis);
		
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

		ChartUtilities.writeChartAsPNG(outputStream, chart, 
				chartWidth, chartHeight);
		outputStream.close();
		
		return outFile;
	}
	
	private CategoryPlot createPageResponseTimePlot() {
			
		String[] levelTitles = new String[] {
			"Minimum", "Maximum", "Average" 	
		};
		
		Color[] levelColors = new Color[] {
				minimumColor, maximumColor, averageColor	
		};
		
		CategoryPlot plot = new CategoryPlot();
		plot.setRangeAxis(new NumberAxis("Response Times (ms)"));
		
		// ninety percentile bar
		CategoryDataset ninetyPercentile = DatasetUtilities.createCategoryDataset(
				new String[] { "90 percentile" }, 
				pages, 
				new double[][] { responseTimeData[3] });
		BarRenderer barRenderer = new BarRenderer();
		barRenderer.setSeriesPaint(0, ninetyPercentileColor);
		barRenderer.setShadowVisible(false);
		barRenderer.setBarPainter(new StandardBarPainter());
		plot.setDataset(0, ninetyPercentile);
		plot.setRenderer(0, barRenderer);
		
		for (int i = 0; i < levelTitles.length; i++) {
			addLevel(plot, i + 1, levelTitles[i], i, levelColors[i]);
		}
		
		plot.setDatasetRenderingOrder(DatasetRenderingOrder.FORWARD);
		
		return plot;
	}
	
	private void addLevel(CategoryPlot plot, int plotIndex, String title, 
			int responseDataIndex, Color color) {

		CategoryDataset dataset = DatasetUtilities.createCategoryDataset(
				new String[] { title },
				pages,
				new double[][] { responseTimeData[responseDataIndex] });
		
		LevelRenderer renderer = new LevelRenderer();
		renderer.setSeriesPaint(0, color);
		renderer.setSeriesStroke(0, new BasicStroke(2.0f));
		
		plot.setDataset(plotIndex, dataset);
		plot.setRenderer(plotIndex, renderer);
	}

	private CategoryPlot createPageFiguresPlot() {
		
		List<Color> thresholdColors = new ArrayList<Color>(thresholdTitles.length);
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
		
		CategoryDataset dataSet = DatasetUtilities.createCategoryDataset(
				thresholdTitles, pages, thresholdData);
		
		StackedBarRenderer renderer = new StackedBarRenderer();
		for (int i = 0; i < thresholdColors.size(); i++) {
			renderer.setSeriesPaint(i, thresholdColors.get(i));
		}
		renderer.setShadowVisible(false);
		renderer.setBarPainter(new StandardBarPainter());
		
		CategoryPlot plot = new CategoryPlot(dataSet, null, 
				new NumberAxis("% requests"), renderer);
		
		plot.getRangeAxis().setTickLabelsVisible(false);
		
		return plot;
	}
	
	// response time metric colors
	private static final Color minimumColor = Color.orange;
	private static final Color maximumColor = new Color(171, 171, 171);
	private static final Color averageColor = Color.yellow;
	private static final Color ninetyPercentileColor = new Color(0, 0, 255);
	

}
