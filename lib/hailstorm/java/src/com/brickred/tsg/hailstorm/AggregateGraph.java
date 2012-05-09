package com.brickred.tsg.hailstorm;

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
import org.jfree.chart.axis.ValueAxis;
import org.jfree.chart.plot.CategoryPlot;
import org.jfree.chart.plot.CombinedDomainCategoryPlot;
import org.jfree.chart.plot.PlotOrientation;
import org.jfree.chart.renderer.category.LayeredBarRenderer;
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
		
		CombinedDomainCategoryPlot plot = new CombinedDomainCategoryPlot(
				new CategoryAxis("Pages"));
		
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
			
		String[] titles = new String[] {
			"Minimum", "Maximum", "Average", "90 percentile" 	
		};
		
		double[] titleWidths = new double[] {
			1.0, 0.5, 0.45, 0.15	
		};
		
		Color[] titleColors = new Color[] {
				minimumColor, maximumColor, averageColor, ninetyPercentileColor	
		};
		
		CategoryDataset pageStats = DatasetUtilities.createCategoryDataset(
				titles, pages, responseTimeData);
		
		ValueAxis valueAxis = new NumberAxis("Response Times (ms)");
		
		LayeredBarRenderer renderer = new LayeredBarRenderer();
		// set widths
		for (int i = 0; i < titleWidths.length; i++) {
			renderer.setSeriesBarWidth(i, titleWidths[i]);
		}
		// set colors
		for (int i = 0; i < titleColors.length; i++) {
			renderer.setSeriesPaint(i, titleColors[i]);
		}
		
		CategoryPlot plot = new CategoryPlot(pageStats, null, 
				valueAxis, renderer);

		return plot;
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
	private static final Color minimumColor = new Color(185, 186, 124);
	private static final Color maximumColor = new Color(171, 171, 171);
	private static final Color averageColor = new Color(102, 255, 255);
	private static final Color ninetyPercentileColor = new Color(0, 0, 255);
	

}
