--Github installer--
ProgramName='BIM'
ToDownload={
  {--github raw url base
    'https://raw.githubusercontent.com/DragonVoyageur/BIM/main',
    {--directory of github to install, it will have the same name when installed
      '/Startup/StartBIM.lua',
      '/BIM/CrafterManager.lua',
      '/BIM/InventoryManager.lua',
      '/BIM/SettingsManager.lua',
      '/BIM/Functions/UiManager.lua',
      '/BIM/Functions/VariableStorage.lua',
      '/BIM/Functions/StorageSystem.lua',
      '/BIM/CraftingMenu.lua'
    }
  }
}
Run='/Startup/StartBIM.lua'--File to run to start program
--Thanks to Fatboychummy, for showing me his installer code to help me make mine
-------------------------
Files={}
print('Downloading files')
for _,link in ipairs(ToDownload) do
  for _,directory in ipairs(link[2]) do
    local file=http.get(link[1]..directory)
    if file and file.getResponseCode() == 200 then
      table.insert(Files,{directory,file.readAll()})
      file.close()
    else
      error('Failed to download file '..link[1]..directory)
    end
  end
end
--------------
print('Installing files')
for _,file in ipairs(Files) do
  local install = fs.open(file[1], 'w')
  if install then
    install.write(file[2])
    install.close()
  else
    error("Failed to open " .. file[1] .. " for writing") -- in case of read only / disk full etc.
  end
end
---------------
print('Done')
if Run then
  print('Running program')
 if fs.exists(Run) then
  shell.run(Run)
 else
  printError('Startup file not found, '..Run)
 end
end