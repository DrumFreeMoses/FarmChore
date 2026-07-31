package main

import (
	"encoding/json"
)

func (c *client) handleEvent(msg []json.RawMessage) {
	if len(msg) != 2 {
		c.sendNotice("EVENT requires exactly 2 elements")
		return
	}
	var e Event
	if err := json.Unmarshal(msg[1], &e); err != nil {
		c.sendNotice("invalid event json")
		return
	}
	if err := e.Validate(); err != nil {
		c.sendOK(e.ID, false, "invalid: "+err.Error())
		return
	}
	saved, err := c.relay.store.Save(&e)
	if err != nil {
		c.sendOK(e.ID, false, "error: "+err.Error())
		return
	}
	if !saved {
		c.sendOK(e.ID, false, "duplicate")
		return
	}
	c.sendOK(e.ID, true, "")
	c.relay.broadcast(&e)
}

func (c *client) handleReq(msg []json.RawMessage) {
	if len(msg) < 3 {
		c.sendNotice("REQ requires a subscription id and at least one filter")
		return
	}
	var subID string
	if err := json.Unmarshal(msg[1], &subID); err != nil {
		c.sendNotice("invalid subscription id")
		return
	}
	c.subs[subID] = struct{}{}
	events := []Event{}
	for _, raw := range msg[2:] {
		var f Filter
		if err := json.Unmarshal(raw, &f); err != nil {
			c.sendNotice("invalid filter")
			continue
		}
		got, err := c.relay.store.Query(f)
		if err != nil {
			c.sendNotice("query error")
			continue
		}
		events = append(events, got...)
	}
	for _, e := range events {
		payload, _ := json.Marshal([]any{"EVENT", subID, e})
		c.send <- payload
	}
	eose, _ := json.Marshal([]any{"EOSE", subID})
	c.send <- eose
}

func (c *client) handleClose(msg []json.RawMessage) {
	if len(msg) != 2 {
		return
	}
	var subID string
	if err := json.Unmarshal(msg[1], &subID); err != nil {
		return
	}
	delete(c.subs, subID)
}
