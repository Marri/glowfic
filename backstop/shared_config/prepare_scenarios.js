const domain = "http://web:3000/";

module.exports = function prepareScenarios(scenarioOriginal) {
  const scenario = Object.assign({}, scenarioOriginal); // clone to prevent mutating original
  scenario.cookiePath = "engine_scripts/cookies.json";

  // path -> url
  scenario.url = domain.concat(scenario.path);
  delete scenario.path;
  if (scenario.url.includes('?')) {
    scenario.url = scenario.url.concat('&pp=skip');
  } else {
    scenario.url = scenario.url.concat('?pp=skip');
  }

  // ignore selectors to allow sensible diffs
  var removeSelectors = ['.time-loaded', '.profiler-results'];
  if (('selectors' in scenario) && scenario.selectors.includes("#content")) {
    removeSelectors.push("#footer");
  }
  scenario.removeSelectors = removeSelectors.concat(scenario.removeSelectors || []);

  // add default delay
  if (!('delay' in scenario)) {
    scenario.delay = 200;
  }

  // increase default misMatchThreshold
  if (!('misMatchThreshold' in scenario)) {
    scenario.misMatchThreshold = 0.01
  }

  return scenario;
};
