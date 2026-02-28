class RoomsController < ApplicationController
  before_action :set_current_tenant

  def index
    @floors = Current.organization.rooms.active.distinct.pluck(:floor).sort
    @floor  = params[:floor] || @floors.first
    @rooms  = @floor ? Current.organization.rooms.active.where(floor: @floor) : []
  end
end
