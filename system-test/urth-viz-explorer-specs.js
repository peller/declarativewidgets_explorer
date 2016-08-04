// Copyright (c) Jupyter Development Team.
// Distributed under the terms of the Modified BSD License.

var wd = require('wd');
var chai = require('chai');
var Boilerplate = require('./utils/boilerplate');
var boilerplate = new Boilerplate();

describe('Urth Viz Explorer Test', function() {

    var tagChaiAssertionError = function(err) {
        // throw error and tag as retriable to poll again
        err.retriable = err instanceof chai.AssertionError;
        throw err;
    };

    wd.PromiseChainWebdriver.prototype.waitForWidgetElement = function(selector, browserSupportsShadowDOM, timeout, pollFreq) {
        return this.waitForElementByCssSelector(
            browserSupportsShadowDOM ? 'urth-viz-explorer::shadow urth-viz-vega::shadow svg' : 'urth-viz-explorer urth-viz-vega svg',
            wd.asserters.isDisplayed,
            timeout)
        .catch(tagChaiAssertionError);
    };

    boilerplate.setup(this.title, '/notebooks/examples/urth-viz-explorer.ipynb');

    it('should run all cells and find an explorer in the 5th output area', function(done) {
        boilerplate.browser
            .waitForElementsByCssSelector('div.output_area').nth(5)
            .waitForWidgetElement("urth-viz-explorer", boilerplate.browserSupportsShadowDOM, 10000)
            .nodeify(done);
    });

    it('should have 20 items plotted, by default, then 10 after setting the limit accordingly', function(done) {
        boilerplate.browser
            .waitForElementsByCssSelector('div.output_area').nth(7)
            .moveTo()
            .waitForElementsByCssSelector('urth-viz-explorer#v1::shadow urth-viz-vega::shadow svg .marks *', wd.asserters.isDisplayed, 10000)
            .should.be.eventually.length(20)
            .waitForElementByCssSelector('urth-viz-explorer#v1::shadow #viz-explorer-controls .viz-explorer-controls-section paper-input[label=Limit]::shadow paper-input-container #input', wd.asserters.isDisplayed, 10000)
            .click()
            .doubleclick()
            .type('10')
            .sleep(1000)
            .elementsByCssSelector('urth-viz-explorer#v1::shadow urth-viz-vega::shadow svg .marks *')
            .should.be.eventually.length(10)
            .nodeify(done);
    });
});
