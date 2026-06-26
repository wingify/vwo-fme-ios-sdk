
Pod::Spec.new do |spec|

  spec.name         	= "Wingify-FME"
  spec.version      	= "1.55.0"
  spec.summary      	= "Wingify iOS SDK for Feature Management and Experimentation"
  spec.description  	= "Wingify iOS SDK for Feature Management and Experimentation."

  spec.homepage     	= "https://developers.vwo.com/"

  spec.license      	= {  :type => 'Apache-2.0',
                                 :file => 'LICENSE',
                                 :text => 'Licensed under the Apache License, Version 2.0. See LICENSE in the project root for license information.'
                      		}

  spec.author       	= { 'VWO' => 'dev@wingify.com' }
  spec.platforms     	= { :ios => "12.0", :tvos => "12.0", :osx => "10.14", :watchos => "7.0" }
  spec.swift_version 	= '5.0'
  spec.source       	= { :git => "https://github.com/wingify/vwo-fme-ios-sdk.git", :tag => "#{spec.version}" }
  spec.source_files 	= 'Wingify-FME/**/*.{h,m,swift,json}'
  spec.resources 	= ['Wingify-FME/Resources/*.json', 'Wingify-FME/CoreData/Model/OffineEventData.xcdatamodeld']

end
