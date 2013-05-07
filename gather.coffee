class Config
	constructor: ()->
		@config = {}
		@load()
	load: ->
		@config = JSON.parse GM_getValue 'config', '{}'
		if !@config.cities
			@config.cities = []
	save: ->
		GM_setValue 'config', JSON.stringify @config
	getCity: (city_id)->
		for c, i in @config.cities
			if c.id == city_id
				city = new City c
				@config.cities[i] = city
				return city
		city = new City id: city_id
		@config.cities.push city
		city

class City
	constructor: (props)->
		$.extend @, props
	tradegood_name: ->
		TRADEGOOD_NAMES[@tradegood]
	percent_full: (resource_id, time)->
		Math.floor @resource_amount(resource_id, time) * 100 / @maxResources[resource_id]
	fullness_class: (resource_id, time)->
		percent = @percent_full resource_id, time
		if percent >= 90
			'progress-danger'
		else if percent >= 75
			'progress-warning'
		else
			'progress-success'
	amount_class: (resource_id)->
		'production' if @production_for_resource(resource_id) > 0
	production_for_resource: (resource_id)->
		if resource_id == 'resource'
			@resourceProduction
		else if ''+resource_id == ''+@tradegood
			@tradegoodProduction
		else
			0
	resource_amount: (resource_id, time)->
		delta_t = (time - @time) / 1000.0
		increase = delta_t * @production_for_resource(resource_id)
		amount = Math.round @currentResources[resource_id] + increase
		Math.min amount, @maxResources[resource_id]
	getBuilding: (building_id)->
		if !@buildings
			@buildings = {}
		if !@buildings[building_id]
			@buildings[building_id] = new Building id: building_id
		else
			@buildings[building_id] = new Building @buildings[building_id]
		@buildings[building_id]

class Building
	constructor: (props)->
		$.extend @, props

copy = (object)->
	$.extend {}, object

TRADEGOOD_NAMES =
	resource: 'wood'
	1: 'wine'
	2: 'marble'
	3: 'glass'
	4: 'sulfur'
BUILDINGS = ['townHall', 'academy', 'warehouse', 'tavern', 'palace', 'palaceColony', 'museum',
	'port', 'shipyard', 'barracks', 'wall', 'embassy', 'branchOffice', 'workshop', 'safehouse',
	'forester', 'glassblowing', 'alchemist', 'winegrower', 'stonemason', 'carpentering',
	'optician', 'fireworker', 'vineyard', 'architect', 'temple', 'dump', 'pirateFortress']

gatherData = (domain)->
	config = new Config()
	c = config.config

	ikariam = unsafeWindow.ikariam
	if !ikariam
		return console.log 'Cannot access Ikariam data'

	m = ikariam.getModel()

	if m.gold
		c.gold = parseFloat(m.gold)
	if m.freeTransporters
		c.freeTransporters = m.freeTransporters

	if m.isOwnCity
		city = config.getCity(m.relatedCityData.selectedCity)
		m_city = m.relatedCityData[city.id]
		city.name = m_city.name
		city.coords = m_city.coords
		city.tradegood = m_city.tradegood
		city.maxResources = copy m.maxResources
		city.time = 1 * new Date()
		city.currentResources = copy m.currentResources
		city.resourceProduction = m.resourceProduction
		city.tradegoodProduction = m.tradegoodProduction
		city.wineSpendings = m.wineSpendings

	# console.log c
	config.save()

updateGlobalData = (config, domain, data)->
	console.log 'update:', data
	bg = data.backgroundData
	city = config.getCity 'city_' + bg.id
	# console.log city
	for b in bg.position
		building = city.getBuilding b.building
		building.isBusy = b.isBusy
		building.level = b.level
		building.name = b.name
	# console.log 'after buildings update:', city
	m = data.headerData
	city.maxResources = copy m.maxResources
	city.time = 1 * new Date()
	city.currentResources = copy m.currentResources
	city.resourceProduction = m.resourceProduction
	city.tradegoodProduction = m.tradegoodProduction
	city.wineSpendings = m.wineSpendings

registerUpdateData = (domain)->
	unsafeWindow.$(unsafeWindow.document).ajaxSuccess (event, xhr, settings)->
		data = JSON.parse(xhr.responseText)
		# console.log "Triggered ajaxSuccess handler", data, settings
		for row in data
			if row[0] == 'updateGlobalData'
				config = new Config()

				updateGlobalData config, domain, row[1]

				# console.log c
				config.save()
			else
				console.log row[0], row[1]

render = (domain)->
	unsafeWindow.skip = true
	console.log 'render', domain

	config = new Config()
	c = config.config
	console.log c

	view = GM_getResourceText('view')
	document.body.parentElement.innerHTML = view

	app = angular.module 'MyApp', ['ui.bootstrap']
	window.AppController = (scope, $timeout)->
		scope.show_buildings = true
		scope.domain = domain
		scope.BUILDINGS = BUILDINGS
		scope.TRADEGOOD_NAMES = TRADEGOOD_NAMES
		scope.cities = c.cities.map (city_props)->
			new City city_props
		scope.time = 1 * new Date()
		window.setInterval ->
			scope.$apply(-> scope.time = 1 * new Date())
		, 5000
	window.AppController.$inject = ['$scope', '$timeout']
	angular.bootstrap document, ['MyApp']

url = window.location.href
if /^https?:\/\/([^\/]*ikariam\.[^\/]+)\//.exec url
	domain = RegExp.$1
	gatherData domain
	registerUpdateData domain
else if /^https?:\/\/[^\/]+\/([^\/]*ikariam\.[^\/]+)/.exec url
	domain = RegExp.$1
	render domain

