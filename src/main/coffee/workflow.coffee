require('coffee-script')

log = (args...) ->
	#console.log.apply console, args

log "Starting"

AlfredNode = require 'alfred-workflow-nodejs'
AWS = require 'aws-sdk'
_ = require 'lodash'


# AWS.Config object
unless AWS.config.region
	AWS.config.update
		region: process.env.AWS_DEFAULT_REGION or 'us-east-1'

ec2 = new AWS.EC2()
workflow = AlfredNode.workflow
workflow.setName('AWS Goodies')

handler = AlfredNode.actionHandler
Item = AlfredNode.Item

searchInstances = (query, fn) ->
	log "Searching with query #{query}"
	params =
		Filters: [
			Name: 'tag:Name'
			Values: [
				"*#{query}*"
			]
		]


	ec2.describeInstances params, (err,data) ->
		switch
			when fn then fn(err,data)
			when err then log err.message,err,err.stack
			else log JSON.stringify(data, null, 4)



searchInstances 'prod-event'

errorHandler = (fn) ->
	(err, data) ->
		switch
			when err
				workflow.error err.message, JSON.stringify(err.stack)
				workflow.feedback()
			else fn(data)

handler.onAction 'searchInstances', (query) ->
	searchInstances query, errorHandler (data) ->
		log "Starting results", data
		for reservation, i in data.Reservations
			log "Reservation #{i}"
			for instance, j in reservation.Instances
				log "Reservation #{j}"
				tags = {}
				tags[tag.Key] = tag.Value for tag in instance.Tags

				details = [
					tags['opsworks:stack']
					tags['opsworks:instance']
					instance.InstanceId
				]

				details = (detail for detail in details when detail)


				item = new Item
					title: tags.Name or tags[''] or instance.InstanceId
					subtitle: details.join ' -- '
					arg: instance.PublicIpAddress
					valid: true
					data: instance

				workflow.addItem item

		workflow.feedback()

AlfredNode.run()