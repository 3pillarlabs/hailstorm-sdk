package com.brickred.tsg.hailstorm;

import java.awt.Color;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.Calendar;
import java.util.GregorianCalendar;

import org.jfree.chart.ChartFactory;
import org.jfree.chart.ChartUtilities;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.renderer.xy.XYLineAndShapeRenderer;
import org.jfree.data.time.Second;
import org.jfree.data.time.TimeSeries;
import org.jfree.data.time.TimeSeriesCollection;

public class TimeSeriesGraph {

	private final TimeSeries timeSeries;
	private String domainName = "Time";
	private final String rangeName;
	private String title = "";
	private final Calendar calendar;
	private final int startTimeSec;
	private boolean drawDataShape = false;

	public TimeSeriesGraph(String seriesName, String rangeName, long startTime) {
		this.timeSeries = new TimeSeries(seriesName);
		this.rangeName = rangeName;
		this.calendar = new GregorianCalendar();
		this.calendar.setTimeInMillis(startTime);
		this.startTimeSec = (int) (startTime / 1000);
	}

	public void setDomainName(String domainName) {
		this.domainName = domainName;
	}

	public void setTitle(String title) {
		this.title = title;
	}

	public void setDrawDataShape(boolean drawDataShape) {
		this.drawDataShape = drawDataShape;
	}

	public void addDataPoint(int ts, int count) {
		int amount = ts - startTimeSec;
		calendar.add(Calendar.SECOND, amount);
		timeSeries.add(new Second(calendar.getTime()), count);
		calendar.add(Calendar.SECOND, -amount);
	}

	public ChartModel build(String graphFilePath, int width, int height)
			throws IOException {

		JFreeChart chart = ChartFactory.createTimeSeriesChart(title,
				domainName, rangeName, new TimeSeriesCollection(timeSeries),
				false, false, false);
		chart.setBackgroundPaint(Color.white);
		chart.getPlot().setBackgroundPaint(Color.white);
		chart.getXYPlot().setDomainGridlinePaint(Color.lightGray);
		chart.getXYPlot().setRangeGridlinePaint(Color.lightGray);
		if (drawDataShape) {
			((XYLineAndShapeRenderer) chart.getXYPlot().getRenderer())
					.setBaseShapesVisible(true);
		}
		((XYLineAndShapeRenderer) chart.getXYPlot().getRenderer())
				.setSeriesPaint(0, Color.orange);

		String outFilePath = String.format("%s.png", graphFilePath);
		OutputStream outStream = new FileOutputStream(outFilePath);
		ChartUtilities.writeChartAsPNG(outStream, chart, width, height);
		outStream.close();

		return new ChartModel(outFilePath, width, height);
	}

}
