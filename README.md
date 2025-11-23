# **LingoBeats Web API**

Web API that allows user to explore *songs*, fetching *lyrics*, and AI-generated *materials* from level-based *vocabularies*.

## **Routes**
### **Root check**
`GET /`
<br>
Status:
* 200: API server running and popular songs returned (happy)
* 404: Popular songs not found (sad)

### **Search for songs**
`GET /songs?category=...&query=...`
<br>
Status:
* 200: Song list returned (happy)
* 404: Songs not found (sad)
* 500: problems finding or storing data (bad)

### **Search for a song information**
`GET /songs/{song_id}`
<br>
Status:
* 200: Song information returned (happy)

### **Search for a song's lyrics**
`GET /songs/{song_id}/lyrics`
<br>
Status:
* 200: Lyrics returned (happy)

### **Search for a song's level**
`GET /songs/{song_id}/level`
<br>
Status:
* 200: Song level returned (happy)