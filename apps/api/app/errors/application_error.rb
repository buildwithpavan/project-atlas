# frozen_string_literal: true

class ApplicationError < StandardError
  attr_reader :status, :type, :title, :detail

  def initialize(title:, detail:, status:, type: "about:blank")
    super(detail)

    @title = title
    @detail = detail
    @status = status
    @type = type
  end
end