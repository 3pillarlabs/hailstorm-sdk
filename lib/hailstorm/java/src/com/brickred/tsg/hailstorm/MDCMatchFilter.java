package com.brickred.tsg.hailstorm;

import org.apache.log4j.Level;
import org.apache.log4j.spi.Filter;
import org.apache.log4j.spi.LoggingEvent;

/**
 * The MDCMatchFilter matches a configured value against the value of a
 * configured key in the MDC of a logging event. The filter admits four options:
 * <b>KeyToMatch</b>, <b>ValueToMatch</b>, <b>ExactMatch</b>,
 * <b>AcceptOnMatch</b>, <b>ThresholdLevel</b>. <br/>
 * <br/>
 * <b>KeyToMatch</b> and <b>ValueToMatch</b> are mandatory properties and
 * correspond to the MDC key and value to match respectively. <br/>
 * <br/>
 * <b>AcceptOnMatch</b> is a boolean property, with default <b>false</b>. When
 * false, the Filter will return {@link Filter#DENY} on a match, else it will
 * return {@link Filter#ACCEPT}.<br/>
 * <br/>
 * <b>ExactMatch</b> is a boolean property which determines the method of
 * matching. If true, ValueToMatch needs to exactly match the MDC value, else a
 * match will occur if ValueToMatch occurs anywhere in the MDC value.<br/>
 * <br/>
 * <b>ThresholdLevel</b> is a dependent option. If the filter is about to return
 * a {@link Filter#DENY} and logging event level is greater or equal to the
 * <b>ThresholdLevel</b> a {@link Filter#ACCEPT} is returned instead. This
 * property enables a use case like "DENY if MDC("foo") == "bar" unless
 * log-level >= WARN.
 * 
 * @author sayantamd
 */
public class MDCMatchFilter extends Filter {

	private String keyToMatch;
	private String valueToMatch;
	private Boolean exactMatch = false;
	private Boolean acceptOnMatch = false;
	private String thresholdLevel;

	public String getKeyToMatch() {
		return keyToMatch;
	}

	public void setKeyToMatch(String keyToMatch) {
		this.keyToMatch = keyToMatch;
	}

	public String getValueToMatch() {
		return valueToMatch;
	}

	public void setValueToMatch(String valueToMatch) {
		this.valueToMatch = valueToMatch;
	}

	public Boolean getExactMatch() {
		return exactMatch;
	}

	public void setExactMatch(Boolean exactMatch) {
		this.exactMatch = exactMatch;
	}

	public Boolean getAcceptOnMatch() {
		return acceptOnMatch;
	}

	public void setAcceptOnMatch(Boolean acceptOnMatch) {
		this.acceptOnMatch = acceptOnMatch;
	}

	public String getThresholdLevel() {
		return thresholdLevel;
	}

	public void setThresholdLevel(String thresholdLevel) {
		this.thresholdLevel = thresholdLevel;
	}

	@Override
	public int decide(LoggingEvent event) {

		int decision = Filter.NEUTRAL;

		Object mdcObject = event.getMDC(keyToMatch);
		String mdcValue = null;

		if (mdcObject != null) {
			mdcValue = mdcObject.toString();
		}

		if (mdcValue != null) {
			if ((exactMatch && mdcValue.equals(valueToMatch))
					|| mdcValue.indexOf(valueToMatch) >= 0) {

				decision = acceptOnMatch ? Filter.ACCEPT : Filter.DENY;

				if (decision == Filter.DENY && thresholdLevel != null) {
					Level threshold = Level.toLevel(thresholdLevel);
					if (event.getLevel().isGreaterOrEqual(threshold)) {
						decision = Filter.ACCEPT;
					}
				}
			}
		}

		return decision;
	}

}
