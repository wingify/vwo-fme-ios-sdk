
Pod::Spec.new do |spec|

  spec.name         	= "VWO-FME"
  spec.version      	= "1.3.0"
  spec.summary      	= "VWO iOS SDK for Feature Management and Experimentation"
  spec.description  	= "VWO iOS SDK for Feature Management and Experimentation."

  spec.homepage     	= "https://developers.vwo.com/"

  spec.license      	= {  :type => 'Apache-2.0',
                                 :file => 'LICENSE',
                                 :text => 'Licensed under the Apache License, Version 2.0. See LICENSE in the project root for license information.'
                      		}

  spec.author       	= { 'VWO' => 'dev@wingify.com' }
  spec.platform     	= :ios, "12.0"
  spec.swift_version 	= '5.0'
  spec.source       	= { :git => "https://github.com/wingify/vwo-fme-ios-sdk.git", :tag => "#{spec.version}" }
  spec.source_files 	= 'VWO-FME/**/*.{h,m,swift,json}'
  spec.resources 	= ['VWO-FME/Resources/*.json']

end
