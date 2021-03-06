description 'Asset manager'

class Olelo::Application
  @assets = {}
  @scripts = {}

  class << self
    attr_reader :assets, :scripts
  end

  hook :layout, 1 do |name, doc|
    css = Application.scripts['css']
    if css
      path = absolute_path "_/assets/assets.css?#{css.first.to_i}"
      doc.css('head').first << %{<link rel="stylesheet" href="#{escape_html path}" type="text/css"/>}
    end
    js = Application.scripts['js']
    if js
      path = absolute_path "_/assets/assets.js?#{js.first.to_i}"
      doc.css('body').first << %{<script src="#{escape_html path}" type="text/javascript"/>}
    end
  end

  get "/_/assets/assets.:type", :type => 'js|css' do
    if script = Application.scripts[params[:type]]
      cache_control :last_modified => script.first, :max_age => :static
      response['Content-Type'] = MimeMagic.by_extension(params[:type]).to_s
      response['Content-Length'] = script.last.bytesize.to_s
      script.last
    else
      :not_found
    end
  end

  get "/_/assets/:name", :name => '.*' do
    if asset = Application.assets[params[:name]]
      cache_control :last_modified => asset.mtime, :max_age => :static
      response['Content-Type'] = asset.mime.to_s
      response['Content-Length'] = asset.size.to_s
      halt asset.open
    else
      :not_found
    end
  end
end

class Olelo::Plugin
  def export_assets(*files)
    plugin_fs.glob(*files) do |file|
      Application.assets[File.dirname(name)/file.name] = file
    end
  end

  def export_scripts(*files)
    plugin_fs.glob(*files) do |file|
      raise 'Invalid script type' if file.name !~ /\.(css|js)$/
      scripts = Application.scripts[$1].to_a
      Application.scripts[$1] = [[scripts[0], file.mtime].compact.max, "#{scripts[1]}/* #{File.dirname(name)/file.name} */\n#{file.read}\n"]
    end
  end

  def plugin_fs
    UnionFS.new(InlineFS.new(file), DirectoryFS.new(File.dirname(file)))
  end
end
