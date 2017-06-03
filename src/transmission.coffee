# Description:
#   Interacting with Transmission with hubot.
#
# Configuration:
#   TRANSMISSION_USER - Username for Transmission connection
#   TRANSMISSION_PASS - Password for Transmission connection
#   TRANSMISSION_HOST - Transmission connection host
#   TRANSMISSION_PORT - Transmission connection port
#   TRANSMISSION_USE_SSL - Should use SSL for connection
#   TRANSMISSION_URL - Transmission connection url
#
# Commands:
#   hubot trs add-magnet <magnet-url> - Adds a torrent from magnet.
#   hubot trs start <torrent-id> - Starts a torrent.
#   hubot trs stat <torrent-id> - Gets stat of a torrent.
#   hubot trs list-active - Lists all active torrents.
#
# Author:
#   hbc <me@hbc.rocks>

Transmission = require 'transmission'


setOptWhenEnvDefined = (opts, envvar, assignVar) ->
  if process.env[envvar]?
    o = {}
    o[assignVar] = process.env[envvar]

    Object.assign {}, opts, o
  else
    opts


class HubotTransmission

  constructor: (opts) ->
    @trs = new Transmission opts

  parseTorrenStat: (stat) ->
    return {
      id: stat.id
      name: stat.name
      downloadRate: stat.rateDownload / 1000
      uploadRate: stat.rateUpload / 1000
      completed: stat.percentDone * 100
      etaInSeconds: stat.eta
      status: @trs.statusArray[stat.status]
    }

  addFromMagnet: (url) ->
    new Promise (resolve, reject) =>
      @trs.addUrl url, (err, rv) ->
        return reject err if err
        resolve rv

  start: (id) ->
    id = parseInt(id, 10)
    new Promise (resolve, reject) =>
      @trs.start [id], (err, rv) ->
        return reject err if err
        resolve
          id: id

  getStat: (id) ->
    id = parseInt(id, 10)
    new Promise (resolve, reject) =>
      @trs.get id, (err, rv) =>
        return reject err if err
        return reject "torrent #{id} not found" unless rv.torrents?.length > 0

        stat = rv.torrents[0]
        resolve @parseTorrenStat stat

  listActive: () ->
    new Promise (resolve, reject) =>
      @trs.active (err, rv) =>
        return reject err if err
        return resolve [] unless rv.torrents?.length > 0

        resolve rv.torrents.map (t) => @parseTorrenStat t


module.exports = (robot) ->
  opts = {}
  opts = setOptWhenEnvDefined opts, 'TRANSMISSION_USER', 'username'
  opts = setOptWhenEnvDefined opts, 'TRANSMISSION_PASS', 'password'
  opts = setOptWhenEnvDefined opts, 'TRANSMISSION_HOST', 'host'
  opts = setOptWhenEnvDefined opts, 'TRANSMISSION_PORT', 'port'
  opts = setOptWhenEnvDefined opts, 'TRANSMISSION_USE_SSL', 'ssl'
  opts = setOptWhenEnvDefined opts, 'TRANSMISSION_URL', 'url'

  trs = new HubotTransmission opts

  robot.hear /trs add\-magnet (.*)/i, (res) ->
    trs.addFromMagnet(res.match[1].trim())
      .then (torrent) ->
        res.reply [
          "torrent #{torrent.name} added. "
          "You can start with `trs start #{torrent.id}`"
        ].join('')
      .catch (err) ->
        res.reply "add torrent from magnet failed: #{err}"

  robot.hear /trs start (.*)/i, (res) ->
    trs.start(res.match[1].trim())
      .then (torrent) ->
        res.reply "torrent #{torrent.id} started"
      .catch (err) ->
        res.reply "start torrent #{id} failed: #{err}"

  robot.hear /trs stat (.*)/i, (res) ->
    trs.getStat(res.match[1].trim())
      .then (stat) ->
        reply = [
          "torrent #{stat.name} (#{stat.status}):"
          "download rate: #{stat.downloadRate}"
          "upload rate: #{stat.uploadRate}"
          "%: #{stat.completed}"
          "ETA: #{stat.etaInSeconds}s"
        ].join('\n')
        res.reply reply
      .catch (err) ->
        res.reply err

  robot.hear /trs list-active/i, (res) ->
    trs.listActive()
      .then (torrents) ->
        if torrents.length > 0
          ts = torrents.map (t) ->
            "- #{t.id} #{t.name} (#{t.status}/#{t.etaInSeconds}/#{t.completed})"
          res.reply ts.join('\n')
        else
          res.reply 'no active torrents'
      .catch (err) ->
        resp.reply err
