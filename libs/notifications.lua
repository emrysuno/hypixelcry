local notifications = {}

function notifications.snowNotify(title, message)
    threads.startThread(function()
        local notification_command = 'snoretoast -t "' .. title .. '" -m "' .. message .. '"'
        os.execute(notification_command)
    end)
end

function notifications.snowNotifyWithIcon(title, message, icon)
    threads.startThread(function()
        local notification_command = 'snoretoast -t "' .. title .. '" -m "' .. message .. '" -p "' .. icon .. '"'
        os.execute(notification_command)
    end)
end

return notifications
