module QstarzGps


export readQstarzLog

# Structure of a Qstarz BL-1000GT binary file
# Fields are converted from raw format during loading process
# Additional field time in float is generated upon access
struct GpsLogEntry
    mode       :: UInt8   # 1 - Fix not available, 2 - 2D, 3 - 3D
    rcr        :: UInt8   # 'B' - POI, 'T' - time
    time_ms    :: UInt16  # miliseconds
    dLat       :: Float64 # DDDMM.MMMM, but converted during read
    dLon       :: Float64 # DDDMM.MMMM, but converted during read
    time_s     :: UInt32  # time_t units seconds since 1 Jan 1970 (unixtime)
    speed_kmph :: Float32 # Speed in km/h
    height_m   :: Float32 # Height in m
    heading    :: Float32 # Deg
    Gx         :: Float32 # Stored as Int16   # G sensor value in x direction, unit 1/256 of G, but converted during read
    Gy         :: Float32 # Stored as Int16   # G sensor value in y direction, unit 1/256 of G, but converted during read
    Gz         :: Float32 # Stored as Int16   # G sensor value in z direction, unit 1/256 of G, but converted during read
    maxSNR     :: UInt16  
    HDOP       :: Float32
    VDOP       :: Float32
    numSatView :: Int8    # Number of satellites in view
    numSatUse  :: Int8    # Number of satellites used
    fixQual    :: UInt8   # 
                            # 0 - Invalid
                            # 1 - GPS fix (SPS)
                            # 2 - DGPS fix
                            # 3 - PPS fix
                            # 4 - Real Time Kinematic
                            # 5 - Float RTK
                            # 6 - estimated (dead reckoning)(2.3 feature)
                            # 7 - Manual input mode
                            # 8 - Simulation mode
    batPerc    :: Int8    # Battery Percent (gap = 10%)
    unused1    :: UInt32  # Unused Unsigned Int
    unused2    :: UInt32  # Unused Unsigned Int
    
end
    

import Base.read!, Base.getproperty, Base.propertynames

function importread(stream:: IO, dummy :: Type{GpsLogEntry})
    tup = ()
   for field in fieldnames(GpsLogEntry)
        val = 0
        if field == :Gx || field == :Gy || field == :Gz
            val = read(stream, Int16)/256
        else
            val = read(stream, fieldtype(GpsLogEntry, field))
        end
        if field == :dLat || field == :dLon
                
            tmp = trunc(Int64, val / 100)
            val = tmp + (val - tmp*100)/60.0
        end
        tup = (tup..., val)
#            @show field, val
    end
#        @show tup
    GpsLogEntry(tup...)
end

function Base.read!(stream::IO, v::Vector{GpsLogEntry})
   for iter=1:length(v)
        v[iter] = importread(stream, GpsLogEntry) 
   end
end


function Base.propertynames(x :: GpsLogEntry)
    f = fieldnames(typeof(x))
    (f... , :time)
end

function Base.propertynames(x :: Array{GpsLogEntry})
    f = fieldnames(eltype(x))
    (f... , :time)
end

function Base.getproperty(obj :: GpsLogEntry, name::Symbol )
    if name === :time
        return obj.time_s + obj.time_ms*0.001
    else
        return getfield(obj, name)
    end
end

function Base.getproperty(obj :: Array{GpsLogEntry}, name::Symbol )
    if name === :time
        return [getproperty(obj[cnt], name) for cnt=1:length(obj)]
    end
    if hasfield(GpsLogEntry, name)
        return [getfield(obj[cnt], name) for cnt=1:length(obj)]
    end
end

"""    
    readQstarzLog(filename::AbstractString)
    
Reads a Qstarz binary log file into a array of structure object, 
    which is overloaded to be able to be accessed as structure of arrays 

# Example
    
```
julia> using QstarzGps
    
julia> filename = "230502_120613.BIN"
    
julia> gpsLog = readQstarzLog(filename)
5325-element Vector{GpsLogEntry}:
 GpsLogEntry(0x03, 0x54, 0x0258, -25.75720058333333, 28.27944851666667, 0x6450fcb5, 6.7598f0, 1423.27f0, 178.39f0, 0.26171875f0, -0.28515625f0, 0.87109375f0, 0x0031, 1.97f0, 1.0f0, 15, 5, 0x01, 90, 0x00000000, 0x00000000)
 GpsLogEntry(0x03, 0x54, 0x02bc, -25.75720188333333, 28.279449366666668, 0x6450fcb5, 7.5006f0, 1423.351f0, 179.87f0, 0.26171875f0, -0.546875f0, 1.2070312f0, 0x0031, 1.97f0, 1.0f0, 15, 5, 0x01, 90, 0x00000000, 0x00000000)
    ...
   
julia> using Dates
    
julia> unix2datetime.(gpsLog.time[1:3])
3-element Vector{DateTime}:
 2023-05-02T12:06:13.600
 2023-05-02T12:06:13.700
 2023-05-02T12:06:13.800
```    
# Extended Example
For an extended example, check the README or ?QstarzGps
"""    
function readQstarzLog(filename :: AbstractString)    
    filesize= stat(filename).size
    fid = open(filename)

    len = div(filesize,64)
    gps = Array{GpsLogEntry}(undef, len)
    read!(fid, gps)
    close(fid)    
    gps = filter(x->(x.mode != 0x00), gps)  # Discards invalid log entries
end


end
