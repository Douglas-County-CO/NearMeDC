require 'spec_helper'

describe Citygram::Models::Event do
  it 'belongs to a publisher' do
    type = Event.association_reflections[:publisher][:type]
    expect(type).to eq :many_to_one
  end

  it 'whitelists mass-assignable attributes' do
    expect(Event.allowed_columns).to eq [:title, :geom, :description, :properties]
  end

  it 'round trip a geojson geometry through a postgis geometry column' do
    geometry = fixture('subject-geom.geojson')
    event_id = create(:event, geom: geometry).id
    event = Event.first!(id: event_id)
    expect(event.geom).to eq geometry
  end

  it 'requires a title' do
    event = build(:event, title: '')
    expect(event).not_to be_valid
  end

  it 'requires a valid GeoJSON feature geometry' do
    event = build(:event, geom: fixture('invalid-geom.geojson'))
    expect(event).not_to be_valid
  end

  it 'checks if events needs to be updated' do
    old_event = build(:event, title: 'This is an old event')
    new_event = build(:event, title: 'This is a new event')
    expect(old_event.need_update(new_event)).to eq true
  end

  it 'requires a feature_id' do
    event = build(:event, feature_id: '')
    expect(event).not_to be_valid
  end

  it 'requires a unique publisher_id/feature_id combination' do
    feature_id = 'abc123'
    publisher = create(:publisher)
    event = create(:event, publisher_id: publisher.id, feature_id: feature_id)
    duplicate = build(:event, publisher_id: publisher.id, feature_id: feature_id)
    expect(duplicate).not_to be_valid
  end

  describe 'selecting events' do
    let(:polygon) { fixture('subject-geom.geojson') }
    let(:intersecting_point) { fixture('intersecting-geom.geojson') }

    it 'returns events created after a given date' do
      publisher = create(:publisher)
      perfect = create(:event, publisher: publisher, created_at: 1.day.ago, geom: intersecting_point)
      too_old = create(:event, publisher: publisher, created_at: 3.days.ago, geom: intersecting_point)

      geom = GeoRuby::GeojsonParser.new.parse(polygon).as_ewkt
      events = Event.from_geom(geom, {
        publisher_id: publisher.id,
        before_date: 1.days.ago,
        after_date: 2.days.ago
      })

      expect(events.first.title).to eq perfect.title
      expect(events.count).to eq 1
    end

    it 'returns events created before a given date' do
      publisher = create(:publisher)
      too_new = create(:event, publisher: publisher, created_at: 1.day.ago, geom: intersecting_point)
      perfect = create(:event, publisher: publisher, created_at: 3.days.ago, geom: intersecting_point)
      geom = GeoRuby::GeojsonParser.new.parse(polygon).as_ewkt

      events = Event.from_geom(geom, {
        publisher_id: publisher.id,
        before_date: 2.days.ago,
        after_date: 7.days.ago
      })

      expect(events.first.title).to eq perfect.title
      expect(events.count).to eq 1
    end
  end
end
