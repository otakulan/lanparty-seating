defmodule IconComponent do
  use Phoenix.Component

  # Optionally also bring the HTML helpers
  # use Phoenix.HTML

  def left_arrow(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="w-6 h-6"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      stroke-width="2"
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
    </svg>
    """
  end

  def right_arrow(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="w-6 h-6"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      stroke-width="2"
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M14 5l7 7m0 0l-7 7m7-7H3" />
    </svg>
    """
  end

  def double_sided_arrow_horizontal(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="w-6 h-6 mr-1"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      stroke-width="2"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4"
      />
    </svg>
    """
  end

  def double_sided_arrow_vertical(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="w-6 h-6 mr-1"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      stroke-width="2"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4"
      />
    </svg>
    """
  end

  def refresh(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="w-6 h-6 mr-1"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      stroke-width="2"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
      />
    </svg>
    """
  end

  def x(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="w-6 h-6"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      stroke-width="2"
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
    </svg>
    """
  end
end
